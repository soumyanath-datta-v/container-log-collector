# Kubernetes Log Collector

## Overview
The Kubernetes Log Collector is a PowerShell-based script designed to automate the collection of logs from specific Kubernetes pods in the `prod` namespace. It filters out unwanted pods and retrieves logs from the remaining pods, storing the output in a designated log file.

## Project Structure
```
kubernetes-log-collector
├── scripts
│   ├── log-collector.ps1
│   └── helpers
│       ├── kubectl-helpers.ps1
│       └── output-formatting.ps1
├── config
│   └── settings.json
├── logs
│   └── .gitkeep
├── README.md
└── run.ps1
```

## Files Description

- **scripts/log-collector.ps1**: 
  This is the main script that executes the command to get the list of mymobility pods, filters out the unwanted pods (mymobility-apps and mymobility-platform-api), and retrieves logs from the remaining pods. The script runs every 60 minutes and stores the output in `app-state-prod.log`.

- **scripts/helpers/kubectl-helpers.ps1**: 
  This file includes helper functions for executing kubectl commands and handling their output. It simplifies the execution of kubectl commands and manages error handling.

- **scripts/helpers/output-formatting.ps1**: 
  This file contains functions for formatting the output of logs or other data. It includes functions to format timestamps or structure log entries for better readability.

- **config/settings.json**: 
  This file holds configuration settings for the script, such as log file paths or kubectl namespace settings. It allows for easy modification of settings without changing the script code.

- **logs/.gitkeep**: 
  This file is used to ensure that the logs directory is tracked by version control, even if it is empty.

- **README.md**: 
  This file provides documentation for the project, including instructions on how to set up and run the log collector script.

- **run.ps1**: 
  This file serves as an entry point to execute the `log-collector.ps1` script. It may include setup tasks or environment checks before running the main script.

## Usage
1. Ensure you have the necessary permissions to execute kubectl commands in your Kubernetes cluster.
2. Modify the `config/settings.json` file if needed to adjust log file paths or other settings.
3. Run the `run.ps1` script to start the log collection process. The script will run indefinitely, collecting logs every 60 minutes.

## Requirements
- PowerShell
- kubectl installed and configured to access your Kubernetes cluster

## License
This project is licensed under the MIT License. See the LICENSE file for more details.