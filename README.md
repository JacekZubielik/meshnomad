# MeshNomad

[![Flutter and Dart](https://github.com/JacekZubielik/meshnomad/actions/workflows/flutter_dart.yml/badge.svg)](https://github.com/JacekZubielik/meshnomad/actions/workflows/flutter_dart.yml)
[![Build](https://github.com/JacekZubielik/meshnomad/actions/workflows/build.yml/badge.svg)](https://github.com/JacekZubielik/meshnomad/actions/workflows/build.yml)

Independent client for MeshCore-compatible LoRa mesh networking devices.

> **Note on origins**: MeshNomad began as a fork of [MeshCore Open](https://github.com/zjs81/meshcore-open)
> by [zjs81](https://github.com/zjs81), an MIT-licensed open-source client for MeshCore-compatible
> LoRa mesh devices. It has since diverged into an independent project with its own name, branding,
> and roadmap. MeshNomad is not affiliated with, endorsed by, or sponsored by zjs81, Sylvester Corp,
> MeshCore Technologies Limited, Cloudsto Electronics Ltd, or the MeshCore protocol maintainers.
> See [LICENSE](LICENSE) for the original and current copyright notices.

## Overview

MeshNomad is a cross-platform application for communicating with MeshCore-compatible LoRa mesh network devices over Bluetooth Low Energy (BLE), USB, or TCP. The app enables long-range, off-grid communication through peer-to-peer messaging, public channels, and mesh networking capabilities.

## Features

### Core Functionality

- **Direct Messaging**: Private encrypted conversations with individual contacts
- **Public Channels**: Broadcast messages to channel subscribers on the mesh network
- **Contact Management**: Organize contacts, track last seen times, and manage conversation history
- **Contact Groups**: Create custom groups to organize your mesh network contacts
- **Message Reactions**: React to messages with emoji responses
- **Message Replies**: Thread conversations with inline reply functionality

### Mesh Network

- **Path Visualization**: View routing paths and signal quality for each contact
- **Route Management**: Manual path overriding and automatic route rotation
- **Signal Metrics**: Real-time SNR (Signal-to-Noise Ratio) tracking
- **Node Discovery**: Automatic detection of nearby mesh nodes
- **Repeater Support**: Connect to and manage repeater nodes for extended range

### Map & Location

- **Live Map View**: Real-time visualization of mesh network nodes on an interactive map
- **Node Filtering**: Filter by node type (chat, repeater, sensor) and time range
- **Location Sharing**: Share GPS coordinates and custom markers with contacts
- **Offline Maps**: Download map tiles for offline use in remote areas (with [StadiaMaps](https://stadiamaps.com/pricing/) Free Subscription API-Key)
- **MGRS Coordinates**: Support for Military Grid Reference System coordinate format

### Device Management

- **BLE, USB, TCP Connection**: Scan and connect to MeshCore devices via Bluetooth, USB or TCP
- **Device Settings**: Configure radio parameters, power settings, and network options
- **Battery Monitoring**: Real-time battery status with chemistry-specific voltage curves
- **Firmware Flashing**: Flash MeshCore firmware to a device over USB serial

### Repeater Hub

- **CLI Access**: Full command-line interface to repeater nodes
- **Settings Management**: Configure repeater behavior, power limits, and network settings
- **Statistics Dashboard**: View repeater traffic, connected clients, and system health
- **Remote Management**: Administer repeaters from anywhere on the mesh network

## Technical Details

### Architecture

- **Framework**: Flutter 3.44.9 / Dart 3.12.2
- **State Management**: Provider pattern with ChangeNotifier
- **BLE Protocol**: Nordic UART Service (NUS) over Bluetooth Low Energy
- **Storage**: SharedPreferences-backed key-value stores (PrefsManager singleton), scoped per connected device's public key
- **Encryption**: End-to-end encryption for private messages using the MeshCore protocol
