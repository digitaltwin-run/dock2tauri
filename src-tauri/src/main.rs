// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Serialize, Deserialize)]
struct ContainerInfo {
    id: String,
    name: String,
    image: String,
    status: String,
    ports: String,
    created: String,
}

#[derive(Serialize, Deserialize)]
struct DockerResult {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    container_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    containers: Option<Vec<ContainerInfo>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    info: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

// Docker container management commands
#[tauri::command]
async fn launch_docker_container(image: String, host_port: u16, container_port: u16) -> DockerResult {
    println!("Launching Docker container: {} {}:{}", image, host_port, container_port);
    
    // Stop any existing container on the same port
    let _ = Command::new("docker")
        .args(&["ps", "-q", "--filter", &format!("publish={}", host_port)])
        .output()
        .map(|output| {
            if !output.stdout.is_empty() {
                let container_ids = String::from_utf8_lossy(&output.stdout);
                for container_id in container_ids.lines() {
                    let _ = Command::new("docker")
                        .args(&["stop", container_id.trim()])
                        .output();
                }
            }
        });

    // Launch new container
    match Command::new("docker")
        .args(&[
            "run", "-d", 
            "-p", &format!("{}:{}", host_port, container_port),
            "--name", &format!("tauridock-{}-{}", image.replace([':', '/'], "-"), host_port),
            &image
        ])
        .output()
    {
        Ok(output) => {
            if output.status.success() {
                let container_id = String::from_utf8_lossy(&output.stdout).trim().to_string();
                DockerResult {
                    success: true,
                    container_id: Some(container_id),
                    containers: None,
                    info: None,
                    error: None,
                }
            } else {
                let error_msg = String::from_utf8_lossy(&output.stderr);
                DockerResult {
                    success: false,
                    container_id: None,
                    containers: None,
                    info: None,
                    error: Some(format!("Docker launch failed: {}", error_msg)),
                }
            }
        }
        Err(e) => DockerResult {
            success: false,
            container_id: None,
            containers: None,
            info: None,
            error: Some(format!("Failed to execute docker command: {}", e)),
        },
    }
}

#[tauri::command]
async fn stop_docker_container(container_id: String) -> DockerResult {
    println!("Stopping Docker container: {}", container_id);
    
    match Command::new("docker")
        .args(&["stop", &container_id])
        .output()
    {
        Ok(output) => {
            if output.status.success() {
                // Also remove the container
                let _ = Command::new("docker")
                    .args(&["rm", &container_id])
                    .output();
                    
                DockerResult {
                    success: true,
                    container_id: None,
                    containers: None,
                    info: None,
                    error: None,
                }
            } else {
                let error_msg = String::from_utf8_lossy(&output.stderr);
                DockerResult {
                    success: false,
                    container_id: None,
                    containers: None,
                    info: None,
                    error: Some(format!("Docker stop failed: {}", error_msg)),
                }
            }
        }
        Err(e) => DockerResult {
            success: false,
            container_id: None,
            containers: None,
            info: None,
            error: Some(format!("Failed to execute docker stop: {}", e)),
        },
    }
}

#[tauri::command]
async fn get_docker_containers() -> DockerResult {
    println!("Getting Docker containers list");
    
    match Command::new("docker")
        .args(&[
            "ps", "-a",
            "--format", "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}|{{.CreatedAt}}"
        ])
        .output()
    {
        Ok(output) => {
            if output.status.success() {
                let output_str = String::from_utf8_lossy(&output.stdout);
                let mut containers = Vec::new();
                
                for line in output_str.lines() {
                    if !line.trim().is_empty() {
                        let parts: Vec<&str> = line.split('|').collect();
                        if parts.len() >= 6 {
                            containers.push(ContainerInfo {
                                id: parts[0].to_string(),
                                name: parts[1].to_string(),
                                image: parts[2].to_string(),
                                status: parts[3].to_string(),
                                ports: parts[4].to_string(),
                                created: parts[5].to_string(),
                            });
                        }
                    }
                }
                
                DockerResult {
                    success: true,
                    container_id: None,
                    containers: Some(containers),
                    info: None,
                    error: None,
                }
            } else {
                let error_msg = String::from_utf8_lossy(&output.stderr);
                DockerResult {
                    success: false,
                    container_id: None,
                    containers: None,
                    info: None,
                    error: Some(format!("Docker ps failed: {}", error_msg)),
                }
            }
        }
        Err(e) => DockerResult {
            success: false,
            container_id: None,
            containers: None,
            info: None,
            error: Some(format!("Failed to execute docker ps: {}", e)),
        },
    }
}

#[tauri::command]
async fn get_docker_info() -> DockerResult {
    println!("Getting Docker system information");
    
    match Command::new("docker")
        .args(&["system", "info", "--format", "json"])
        .output()
    {
        Ok(output) => {
            if output.status.success() {
                let output_str = String::from_utf8_lossy(&output.stdout);
                match serde_json::from_str::<serde_json::Value>(&output_str) {
                    Ok(json_value) => {
                        // Extract key information
                        let info = serde_json::json!({
                            "version": json_value.get("ServerVersion").unwrap_or(&serde_json::Value::String("Unknown".to_string())),
                            "apiVersion": json_value.get("APIVersion").unwrap_or(&serde_json::Value::String("Unknown".to_string())),
                            "os": json_value.get("OperatingSystem").unwrap_or(&serde_json::Value::String("Unknown".to_string())),
                            "architecture": json_value.get("Architecture").unwrap_or(&serde_json::Value::String("Unknown".to_string())),
                            "memory": format!("{:.2} GB", 
                                json_value.get("MemTotal").unwrap_or(&serde_json::Value::Number(serde_json::Number::from(0)))
                                    .as_u64().unwrap_or(0) as f64 / 1024.0 / 1024.0 / 1024.0),
                            "cpus": json_value.get("NCPU").unwrap_or(&serde_json::Value::Number(serde_json::Number::from(0))),
                            "containersRunning": json_value.get("ContainersRunning").unwrap_or(&serde_json::Value::Number(serde_json::Number::from(0))),
                            "containersTotal": json_value.get("Containers").unwrap_or(&serde_json::Value::Number(serde_json::Number::from(0))),
                            "images": json_value.get("Images").unwrap_or(&serde_json::Value::Number(serde_json::Number::from(0)))
                        });
                        
                        DockerResult {
                            success: true,
                            container_id: None,
                            containers: None,
                            info: Some(info),
                            error: None,
                        }
                    }
                    Err(_) => DockerResult {
                        success: false,
                        container_id: None,
                        containers: None,
                        info: None,
                        error: Some("Failed to parse Docker info JSON".to_string()),
                    }
                }
            } else {
                let error_msg = String::from_utf8_lossy(&output.stderr);
                DockerResult {
                    success: false,
                    container_id: None,
                    containers: None,
                    info: None,
                    error: Some(format!("Docker info failed: {}", error_msg)),
                }
            }
        }
        Err(e) => DockerResult {
            success: false,
            container_id: None,
            containers: None,
            info: None,
            error: Some(format!("Failed to execute docker info: {}", e)),
        },
    }
}

// Legacy greet command (for backward compatibility)
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! Welcome to TauriDock - Docker to Desktop Bridge!", name)
}

#[tauri::command]
fn get_system_info() -> serde_json::Value {
    serde_json::json!({
        "platform": std::env::consts::OS,
        "architecture": std::env::consts::ARCH,
        "family": std::env::consts::FAMILY,
        "tauridock_version": "1.0.0"
    })
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            greet,
            get_system_info,
            launch_docker_container,
            stop_docker_container,
            get_docker_containers,
            get_docker_info
        ])
        .run(tauri::generate_context!())
        .expect("error while running TauriDock application");
}
