# ZKVM Panel - Virtual Machine Management System

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/node.js-18.x-green.svg)](https://nodejs.org/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-blue.svg)]()

A powerful web-based virtual machine management panel built with Node.js, Express, and QEMU/KVM. ZKVM Panel provides an intuitive interface for managing QEMU/KVM virtual machines with cloud-init support.

![ZKVM Panel](https://i.imgur.com/s2JuH0v.png)

## ✨ Features

- **Complete VM Lifecycle Management**
  - Create, start, stop, restart, and delete VMs
  - Reinstall VMs with different OS templates
  - Attach/detach ISO files
  - Resize virtual disks

- **Cloud-Init Support**
  - Pre-configured OS templates (Ubuntu, Debian, Fedora, CentOS, AlmaLinux)
  - Automatic network configuration
  - User creation and password management

- **Network Configuration**
  - Static IPv4 addressing
  - Bridge networking
  - Custom MAC address generation
  - VLAN support

- **Web Console & SSH Terminal**
  - Built-in web-based VNC/console access
  - Direct SSH terminal via WebSocket
  - Real-time log streaming

- **User Management**
  - Role-based access control (Admin/User)
  - Discord OAuth2 integration
  - User profiles and password management

- **Admin Dashboard**
  - System overview and statistics
  - VM management across all users
  - User management and role assignment
  - System settings configuration

- **License System**
  - Secure license key activation
  - Machine-based licensing
  - Offline and online validation

## 🚀 Quick Start

### Installation

```
bash <(curl -fsSL https://raw.githubusercontent.com/zedocxplayz/zkvm/main/v1.sh)

