//! Performance testing and benchmarking utilities

#[cfg(feature = "performance")]
use criterion::{Criterion, BenchmarkId, Throughput};
use std::time::{Duration, Instant};
use crate::TestResult;

/// Performance test configuration
#[derive(Debug, Clone)]
pub struct PerformanceConfig {
    pub sample_size: usize,
    pub measurement_time: Duration,
    pub warm_up_time: Duration,
    pub significance_level: f64,
    pub noise_threshold: f64,
}

impl Default for PerformanceConfig {
    fn default() -> Self {
        Self {
            sample_size: 100,
            measurement_time: Duration::from_secs(5),
            warm_up_time: Duration::from_secs(3),
            significance_level: 0.05,
            noise_threshold: 0.01,
        }
    }
}

/// Performance metrics collector
#[derive(Debug, Clone)]
pub struct PerformanceMetrics {
    pub duration: Duration,
    pub throughput: Option<f64>,
    pub memory_usage: Option<usize>,
    pub cpu_usage: Option<f64>,
}

/// Simple performance timer
pub struct Timer {
    start: Instant,
    name: String,
}

impl Timer {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            start: Instant::now(),
            name: name.into(),
        }
    }

    pub fn elapsed(&self) -> Duration {
        self.start.elapsed()
    }

    pub fn finish(self) -> PerformanceMetrics {
        let duration = self.elapsed();
        println!("Timer '{}' finished in {:?}", self.name, duration);
        
        PerformanceMetrics {
            duration,
            throughput: None,
            memory_usage: None,
            cpu_usage: None,
        }
    }
}

/// Benchmark a function with multiple iterations
pub async fn benchmark_async<F, Fut, T>(
    name: &str,
    iterations: usize,
    mut func: F,
) -> TestResult<PerformanceMetrics>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = TestResult<T>>,
{
    let mut total_duration = Duration::ZERO;
    let mut successful_runs = 0;

    println!("Running benchmark '{}' with {} iterations", name, iterations);

    for i in 0..iterations {
        let start = Instant::now();
        
        match func().await {
            Ok(_) => {
                total_duration += start.elapsed();
                successful_runs += 1;
            }
            Err(e) => {
                eprintln!("Benchmark iteration {} failed: {}", i, e);
            }
        }
    }

    if successful_runs == 0 {
        return Err("All benchmark iterations failed".into());
    }

    let avg_duration = total_duration / successful_runs as u32;
    let throughput = successful_runs as f64 / total_duration.as_secs_f64();

    println!(
        "Benchmark '{}' completed: {} successful runs, avg duration: {:?}, throughput: {:.2} ops/sec",
        name, successful_runs, avg_duration, throughput
    );

    Ok(PerformanceMetrics {
        duration: avg_duration,
        throughput: Some(throughput),
        memory_usage: None,
        cpu_usage: None,
    })
}

/// Memory usage tracking utilities
pub mod memory {
    use super::*;

    /// Track memory usage during function execution
    pub async fn track_memory_usage<F, Fut, T>(func: F) -> TestResult<(T, usize)>
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = TestResult<T>>,
    {
        // Get initial memory usage
        let initial_memory = get_current_memory_usage()?;
        
        // Execute function
        let result = func().await?;
        
        // Get final memory usage
        let final_memory = get_current_memory_usage()?;
        let memory_used = final_memory.saturating_sub(initial_memory);
        
        Ok((result, memory_used))
    }

    #[cfg(target_os = "linux")]
    fn get_current_memory_usage() -> TestResult<usize> {
        use std::fs;
        
        let status = fs::read_to_string("/proc/self/status")?;
        for line in status.lines() {
            if line.starts_with("VmRSS:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    let kb: usize = parts[1].parse()?;
                    return Ok(kb * 1024); // Convert KB to bytes
                }
            }
        }
        Err("Could not parse memory usage from /proc/self/status".into())
    }

    #[cfg(not(target_os = "linux"))]
    fn get_current_memory_usage() -> TestResult<usize> {
        // Fallback for non-Linux systems
        Ok(0)
    }
}

/// Load testing utilities
pub mod load {
    use super::*;
    use tokio::task::JoinSet;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// Load test configuration
    #[derive(Debug, Clone)]
    pub struct LoadTestConfig {
        pub concurrent_users: usize,
        pub duration: Duration,
        pub ramp_up_time: Duration,
        pub requests_per_second: Option<f64>,
    }

    impl Default for LoadTestConfig {
        fn default() -> Self {
            Self {
                concurrent_users: 10,
                duration: Duration::from_secs(30),
                ramp_up_time: Duration::from_secs(5),
                requests_per_second: None,
            }
        }
    }

    /// Load test results
    #[derive(Debug)]
    pub struct LoadTestResults {
        pub total_requests: usize,
        pub successful_requests: usize,
        pub failed_requests: usize,
        pub average_response_time: Duration,
        pub requests_per_second: f64,
        pub error_rate: f64,
    }

    /// Run a load test with the given configuration
    pub async fn run_load_test<F, Fut, T>(
        config: LoadTestConfig,
        request_fn: F,
    ) -> TestResult<LoadTestResults>
    where
        F: Fn() -> Fut + Send + Sync + Clone + 'static,
        Fut: std::future::Future<Output = TestResult<T>> + Send,
        T: Send,
    {
        let start_time = Instant::now();
        let mut tasks = JoinSet::new();
        
        let total_requests = Arc::new(AtomicUsize::new(0));
        let successful_requests = Arc::new(AtomicUsize::new(0));
        let failed_requests = Arc::new(AtomicUsize::new(0));
        let total_response_time = Arc::new(std::sync::Mutex::new(Duration::ZERO));

        // Spawn concurrent users
        for user_id in 0..config.concurrent_users {
            let request_fn = request_fn.clone();
            let duration = config.duration;
            let total_requests = total_requests.clone();
            let successful_requests = successful_requests.clone();
            let failed_requests = failed_requests.clone();
            let total_response_time = total_response_time.clone();

            tasks.spawn(async move {
                let user_start = Instant::now();
                
                // Stagger user start times for ramp-up
                let ramp_delay = config.ramp_up_time.mul_f64(user_id as f64 / config.concurrent_users as f64);
                tokio::time::sleep(ramp_delay).await;

                while user_start.elapsed() < duration {
                    let request_start = Instant::now();
                    total_requests.fetch_add(1, Ordering::Relaxed);

                    match request_fn().await {
                        Ok(_) => {
                            successful_requests.fetch_add(1, Ordering::Relaxed);
                        }
                        Err(_) => {
                            failed_requests.fetch_add(1, Ordering::Relaxed);
                        }
                    }

                    let request_duration = request_start.elapsed();
                    if let Ok(mut total_time) = total_response_time.lock() {
                        *total_time += request_duration;
                    }

                    // Rate limiting if specified
                    if let Some(rps) = config.requests_per_second {
                        let delay = Duration::from_secs_f64(1.0 / rps);
                        tokio::time::sleep(delay).await;
                    }
                }
            });
        }

        // Wait for all tasks to complete
        while let Some(_) = tasks.join_next().await {}

        let test_duration = start_time.elapsed();
        let total_reqs = total_requests.load(Ordering::Relaxed);
        let successful_reqs = successful_requests.load(Ordering::Relaxed);
        let failed_reqs = failed_requests.load(Ordering::Relaxed);

        let average_response_time = if total_reqs > 0 {
            total_response_time.lock().unwrap().div_f64(total_reqs as f64)
        } else {
            Duration::ZERO
        };

        let rps = total_reqs as f64 / test_duration.as_secs_f64();
        let error_rate = if total_reqs > 0 {
            failed_reqs as f64 / total_reqs as f64
        } else {
            0.0
        };

        Ok(LoadTestResults {
            total_requests: total_reqs,
            successful_requests: successful_reqs,
            failed_requests: failed_reqs,
            average_response_time,
            requests_per_second: rps,
            error_rate,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_timer() {
        let timer = Timer::new("test");
        tokio::time::sleep(Duration::from_millis(10)).await;
        let metrics = timer.finish();
        assert!(metrics.duration >= Duration::from_millis(10));
    }

    #[tokio::test]
    async fn test_benchmark_async() {
        let result = benchmark_async("test_benchmark", 5, || async {
            tokio::time::sleep(Duration::from_millis(1)).await;
            Ok(())
        }).await;

        assert!(result.is_ok());
        let metrics = result.unwrap();
        assert!(metrics.duration > Duration::ZERO);
        assert!(metrics.throughput.is_some());
    }

    #[tokio::test]
    async fn test_load_test() {
        use load::*;
        
        let config = LoadTestConfig {
            concurrent_users: 2,
            duration: Duration::from_millis(100),
            ramp_up_time: Duration::from_millis(10),
            requests_per_second: None,
        };

        let results = run_load_test(config, || async {
            tokio::time::sleep(Duration::from_millis(1)).await;
            Ok(())
        }).await;

        assert!(results.is_ok());
        let load_results = results.unwrap();
        assert!(load_results.total_requests > 0);
        assert_eq!(load_results.failed_requests, 0);
    }
}