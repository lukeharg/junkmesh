// junkmesh-exporter: the management plane of a Junkmesh node in one binary.
//
// A node's job is to join the mesh and store data; it should not waste
// cycles rendering dashboards. This service exposes everything a
// self-hosted Prometheus/Grafana (or a curl-wielding human) needs:
//
//	GET /metrics          node + cluster metrics, Prometheus exposition format
//	GET /metrics/garage   Garage's own metrics, proxied from the local admin API
//	GET /api/v1/status    richer JSON for dashboards and CLIs
//	GET /api/v1/discovery every cluster node as Prometheus HTTP-SD, for
//	                      zero-config scraping of the whole mesh
//
// It reads /proc for system stats, the Yggdrasil admin socket (via
// yggdrasilctl) for mesh state, and the Garage admin API on localhost for
// storage health. Configuration is environment variables, set in
// /etc/conf.d/junkmesh-exporter by the installer:
//
//	JM_LISTEN        listen address        (default "[::]:3904")
//	JM_GARAGE_ADMIN  garage admin API URL  (default "http://[::1]:3903")
//	JM_GARAGE_TOKEN  admin bearer token    (default none)
//	JM_DATA_DIR      garage data dir       (default "/var/lib/garage/data")
//
// Reachability is governed by the node firewall (ring 1): the listen port
// is only open to mesh addresses, like Garage itself.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

var version = "dev" // overridden at build time via -ldflags -X main.version

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

var (
	listenAddr  = envOr("JM_LISTEN", "[::]:3904")
	garageAdmin = envOr("JM_GARAGE_ADMIN", "http://[::1]:3903")
	garageToken = os.Getenv("JM_GARAGE_TOKEN")
	dataDir     = envOr("JM_DATA_DIR", "/var/lib/garage/data")
)

var httpClient = &http.Client{Timeout: 5 * time.Second}

// exporterPort is the port this exporter listens on, reused when advertising
// peer nodes for discovery (every node runs the exporter on the same port).
func exporterPort() string {
	if _, port, err := net.SplitHostPort(listenAddr); err == nil && port != "" {
		return port
	}
	return "3904"
}

// ── system stats ────────────────────────────────────────────────────────

// cpuSampler keeps the previous /proc/stat reading so each scrape reports
// utilisation since the last scrape.
type cpuSampler struct {
	mu                sync.Mutex
	prevBusy, prevAll uint64
}

func (c *cpuSampler) percent() float64 {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return -1
	}
	fields := strings.Fields(strings.SplitN(string(data), "\n", 2)[0])
	if len(fields) < 5 || fields[0] != "cpu" {
		return -1
	}
	var all, idle uint64
	for i, f := range fields[1:] {
		v, _ := strconv.ParseUint(f, 10, 64)
		all += v
		if i == 3 || i == 4 { // idle + iowait
			idle += v
		}
	}
	busy := all - idle

	c.mu.Lock()
	defer c.mu.Unlock()
	dBusy, dAll := busy-c.prevBusy, all-c.prevAll
	c.prevBusy, c.prevAll = busy, all
	if dAll == 0 || dAll > all { // first scrape or counter reset
		return 0
	}
	return 100 * float64(dBusy) / float64(dAll)
}

var cpu cpuSampler

func memoryPercent() float64 {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return -1
	}
	var total, avail float64
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Fields(line)
		if len(f) < 2 {
			continue
		}
		v, _ := strconv.ParseFloat(f[1], 64)
		switch f[0] {
		case "MemTotal:":
			total = v
		case "MemAvailable:":
			avail = v
		}
	}
	if total == 0 {
		return -1
	}
	return 100 * (total - avail) / total
}

func uptimeSeconds() float64 {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return -1
	}
	up, _ := strconv.ParseFloat(strings.Fields(string(data))[0], 64)
	return up
}

func diskUsedFree(path string) (used, free int64) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return -1, -1
	}
	bs := int64(st.Bsize)
	total := int64(st.Blocks) * bs
	free = int64(st.Bavail) * bs
	return total - free, free
}

// ── yggdrasil ───────────────────────────────────────────────────────────

func yggdrasilctl(cmd string) map[string]any {
	out, err := exec.Command("yggdrasilctl", "-json", cmd).Output()
	if err != nil {
		return nil
	}
	var m map[string]any
	if json.Unmarshal(out, &m) != nil {
		return nil
	}
	return m
}

func meshState() (address string, peers int) {
	if self := yggdrasilctl("getself"); self != nil {
		address, _ = self["address"].(string)
	}
	peers = -1
	if p := yggdrasilctl("getpeers"); p != nil {
		if list, ok := p["peers"].([]any); ok {
			peers = len(list)
		}
	}
	return
}

// ── garage ──────────────────────────────────────────────────────────────

func garageGet(path string) (*http.Response, error) {
	req, err := http.NewRequest("GET", garageAdmin+path, nil)
	if err != nil {
		return nil, err
	}
	if garageToken != "" {
		req.Header.Set("Authorization", "Bearer "+garageToken)
	}
	return httpClient.Do(req)
}

func garageHealthy() bool {
	resp, err := garageGet("/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)
	return resp.StatusCode == http.StatusOK
}

// garageHealth returns the decoded /v2/GetClusterHealth body, or nil.
// Fields are read defensively — absent fields simply don't appear.
func garageHealth() map[string]any {
	resp, err := garageGet("/v2/GetClusterHealth")
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		io.Copy(io.Discard, resp.Body)
		return nil
	}
	var m map[string]any
	if json.NewDecoder(resp.Body).Decode(&m) != nil {
		return nil
	}
	return m
}

// garageStats returns the decoded /v2/GetClusterStatistics body, or nil.
// This is where cluster-wide object and bucket counts live.
func garageStats() map[string]any {
	resp, err := garageGet("/v2/GetClusterStatistics")
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		io.Copy(io.Discard, resp.Body)
		return nil
	}
	var m map[string]any
	if json.NewDecoder(resp.Body).Decode(&m) != nil {
		return nil
	}
	return m
}

// clusterNode is one entry from /v2/GetClusterStatus's node list.
type clusterNode struct {
	ID       string `json:"id"`
	Hostname string `json:"hostname"`
	Addr     string `json:"addr"` // "[200:…ygg…]:3901" — Garage RPC over the mesh
	IsUp     bool   `json:"isUp"`
}

// garageNodes lists every node Garage knows in the cluster. Each node's RPC
// address is its Yggdrasil address, which is exactly what a management server
// needs to reach that node's exporter — this is the raw material for
// mesh-native discovery.
func garageNodes() []clusterNode {
	resp, err := garageGet("/v2/GetClusterStatus")
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		io.Copy(io.Discard, resp.Body)
		return nil
	}
	var body struct {
		Nodes []clusterNode `json:"nodes"`
	}
	if json.NewDecoder(resp.Body).Decode(&body) != nil {
		return nil
	}
	return body.Nodes
}

func numField(m map[string]any, key string) (float64, bool) {
	if m == nil {
		return 0, false
	}
	v, ok := m[key].(float64)
	return v, ok
}

// ── handlers ────────────────────────────────────────────────────────────

func handleMetrics(w http.ResponseWriter, _ *http.Request) {
	var b strings.Builder
	gauge := func(name, help string, value float64) {
		fmt.Fprintf(&b, "# HELP %s %s\n# TYPE %s gauge\n%s %g\n", name, help, name, name, value)
	}

	gauge("junkmesh_node_up", "1 if the exporter is serving (scrape success implies liveness).", 1)
	gauge("junkmesh_uptime_seconds", "Node uptime in seconds.", uptimeSeconds())
	gauge("junkmesh_cpu_percent", "CPU utilisation percent since previous scrape.", cpu.percent())
	gauge("junkmesh_memory_percent", "Memory in use, percent of MemTotal.", memoryPercent())

	used, free := diskUsedFree(dataDir)
	gauge("junkmesh_storage_used_bytes", "Bytes used on the Garage data filesystem.", float64(used))
	gauge("junkmesh_storage_free_bytes", "Bytes free on the Garage data filesystem.", float64(free))

	_, peers := meshState()
	gauge("junkmesh_mesh_peers", "Number of directly connected Yggdrasil peers (-1 if unknown).", float64(peers))

	healthy := 0.0
	if garageHealthy() {
		healthy = 1
	}
	gauge("junkmesh_garage_healthy", "1 if the local Garage reports quorum on /health.", healthy)
	if h := garageHealth(); h != nil {
		if v, ok := numField(h, "connectedNodes"); ok {
			gauge("junkmesh_garage_connected_nodes", "Cluster nodes currently connected.", v)
		}
		if v, ok := numField(h, "knownNodes"); ok {
			gauge("junkmesh_garage_known_nodes", "Cluster nodes known to the layout.", v)
		}
		if v, ok := numField(h, "partitionsAllOk"); ok {
			gauge("junkmesh_garage_partitions_all_ok", "Partitions with all replicas available.", v)
		}
		if v, ok := numField(h, "partitions"); ok {
			gauge("junkmesh_garage_partitions", "Total data partitions.", v)
		}
	}
	if s := garageStats(); s != nil {
		if v, ok := numField(s, "totalObjectCount"); ok {
			gauge("junkmesh_garage_objects_total", "Objects stored across all buckets in the cluster.", v)
		}
		if v, ok := numField(s, "totalObjectBytes"); ok {
			gauge("junkmesh_garage_object_bytes", "Logical size of stored objects, before dedup/replication.", v)
		}
		if v, ok := numField(s, "bucketCount"); ok {
			gauge("junkmesh_garage_buckets", "Number of buckets in the cluster.", v)
		}
		if v, ok := numField(s, "dataAvail"); ok {
			gauge("junkmesh_garage_data_avail_bytes", "Available object-data space across the cluster.", v)
		}
	}

	fmt.Fprintf(&b,
		"# HELP junkmesh_exporter_build_info Exporter build info.\n"+
			"# TYPE junkmesh_exporter_build_info gauge\njunkmesh_exporter_build_info{version=%q} 1\n",
		version)

	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	io.WriteString(w, b.String())
}

// handleGarageMetrics proxies Garage's own Prometheus metrics (object
// counts, API latencies, resync queues) so one mesh-reachable port serves
// everything; the admin API itself stays bound to localhost.
func handleGarageMetrics(w http.ResponseWriter, _ *http.Request) {
	resp, err := garageGet("/metrics")
	if err != nil {
		http.Error(w, "garage unreachable: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()
	w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func handleStatus(w http.ResponseWriter, _ *http.Request) {
	hostname, _ := os.Hostname()
	address, peers := meshState()
	used, free := diskUsedFree(dataDir)

	garage := map[string]any{"healthy": garageHealthy(), "used_bytes": used, "free_bytes": free}
	if h := garageHealth(); h != nil {
		for _, k := range []string{"status", "knownNodes", "connectedNodes", "storageNodes", "partitions", "partitionsAllOk"} {
			if v, ok := h[k]; ok {
				garage[k] = v
			}
		}
	}
	if s := garageStats(); s != nil {
		if v, ok := s["totalObjectCount"]; ok {
			garage["objects"] = v
		}
		if v, ok := s["totalObjectBytes"]; ok {
			garage["used"] = v
		}
		if v, ok := s["bucketCount"]; ok {
			garage["buckets"] = v
		}
	}

	body := map[string]any{
		"node":    hostname,
		"version": version,
		"uptime":  int64(uptimeSeconds()),
		"mesh":    map[string]any{"ipv6": address, "peers": peers},
		"garage":  garage,
	}
	w.Header().Set("Content-Type", "application/json")
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.Encode(body)
}

// handleDiscovery is mesh-native service discovery. Because every node's
// Garage RPC address IS its Yggdrasil address, any single node already knows
// how to reach every other node's exporter. A management server points
// Prometheus `http_sd_configs` at ONE node's /api/v1/discovery and gets the
// whole cluster back — no hand-maintained target list, no central registry,
// membership changes followed automatically. The response is Prometheus HTTP
// SD format, which Datadog/Grafana Agent/OTel's prometheus receiver also read.
func handleDiscovery(w http.ResponseWriter, _ *http.Request) {
	type group struct {
		Targets []string          `json:"targets"`
		Labels  map[string]string `json:"labels,omitempty"`
	}
	port := exporterPort()
	groups := []group{}
	for _, n := range garageNodes() {
		if n.Addr == "" {
			continue
		}
		host, _, err := net.SplitHostPort(n.Addr)
		if err != nil {
			continue
		}
		labels := map[string]string{"__meta_junkmesh_node_id": n.ID}
		if n.Hostname != "" {
			labels["__meta_junkmesh_hostname"] = n.Hostname
		}
		if n.IsUp {
			labels["__meta_junkmesh_up"] = "true"
		} else {
			labels["__meta_junkmesh_up"] = "false"
		}
		groups = append(groups, group{
			Targets: []string{net.JoinHostPort(host, port)},
			Labels:  labels,
		})
	}
	w.Header().Set("Content-Type", "application/json")
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.Encode(groups)
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /metrics", handleMetrics)
	mux.HandleFunc("GET /metrics/garage", handleGarageMetrics)
	mux.HandleFunc("GET /api/v1/status", handleStatus)
	mux.HandleFunc("GET /api/v1/discovery", handleDiscovery)
	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		io.WriteString(w, "junkmesh-exporter "+version+
			"\n/metrics /metrics/garage /api/v1/status /api/v1/discovery\n")
	})

	log.Printf("junkmesh-exporter %s listening on %s", version, listenAddr)
	log.Fatal(http.ListenAndServe(listenAddr, mux))
}
