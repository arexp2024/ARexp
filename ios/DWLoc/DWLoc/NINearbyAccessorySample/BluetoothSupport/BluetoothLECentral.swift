import Foundation

import CoreBluetooth
import simd
import os

struct TransferService {
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let txCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
}

struct QorvoNIService {
    static let serviceUUID = CBUUID(string: "2E938FD0-6A61-11ED-A1EB-0242AC120002")
    
    static let scCharacteristicUUID = CBUUID(string: "2E93941C-6A61-11ED-A1EB-0242AC120002")
    static let rxCharacteristicUUID = CBUUID(string: "2E93998A-6A61-11ED-A1EB-0242AC120002")
    static let txCharacteristicUUID = CBUUID(string: "2E939AF2-6A61-11ED-A1EB-0242AC120002")
}


// Base struct to save the last location values
struct Location {
    var distance: Float
    var direction: simd_float3
    var noUpdate: Bool
}

class qorvoDevice {
    var blePeripheral: CBPeripheral         // BLE Peripheral instance
    var rxCharacteristic: CBCharacteristic? // Characteristics to be used when receiving data
    var txCharacteristic: CBCharacteristic? // Characteristics to be used when sending data

    var bleUniqueID: Int
    var blePeripheralName: String            // Name to display
    var blePeripheralStatus: String?         // Status to display
    var bleTimestamp: Int64                  // Last time that the device adverstised
    var uwbLocation: Location?
    
    init(peripheral: CBPeripheral, uniqueID: Int, peripheralName: String, timeStamp: Int64 ) {
        
        self.blePeripheral = peripheral
        self.bleUniqueID = uniqueID
        self.blePeripheralName = peripheralName
        self.blePeripheralStatus = statusDiscovered
        self.bleTimestamp = timeStamp
        self.uwbLocation = Location(distance: 0,
                                    direction: SIMD3<Float>(x: 0, y: 0, z: 0),
                                    noUpdate: false)
    }
}

enum BluetoothLECentralError: Error {
    case noPeripheral
}

let statusDiscovered = "Discovered"
let statusConnected = "Connected"
let statusRanging = "Ranging"

var qorvoDevices = [qorvoDevice?]()

class DataCommunicationChannel: NSObject {
    var centralManager: CBCentralManager!

    var writeIterationsComplete = 0
    var connectionIterationsComplete = 0
    
    // The number of times to retry scanning for accessories.
    // Change this value based on your app's testing use case.
    let defaultIterations = 5
    
    var accessoryDiscoveryHandler: ((Int) -> Void)?
    var accessoryTimeoutHandler: ((Int) -> Void)?
    var accessoryConnectedHandler: ((Int) -> Void)?
    var accessoryDisconnectedHandler: ((Int) -> Void)?
    var accessoryDataHandler: ((Data, String, Int) -> Void)?

    var bluetoothReady = false
    var shouldStartWhenReady = false

    let logger = os.Logger(subsystem: "com.example.apple-samplecode.NINearbyAccessorySample", category: "DataChannel")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        
        // Initialises the Timer used for Haptic and Sound feedbacks
        _ = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(timerHandler), userInfo: nil, repeats: true)
    }
    
    deinit {
        centralManager.stopScan()
        logger.info("Scanning stopped.")
    }
    
    // Clear peripherals in qorvoDevices[] if not responding for more than one second
    @objc func timerHandler() {
        var index = 0
        
        qorvoDevices.forEach { (qorvoDevice) in
            
            if qorvoDevice!.blePeripheralStatus == statusDiscovered {
                // Get current timestamp
                let timeStamp = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
                
                // Remove device if timestamp is bigger than 5000 msec
                if timeStamp > (qorvoDevice!.bleTimestamp + 5000) {
                    let deviceID = qorvoDevice?.bleUniqueID
                    
                    logger.info("Device \(qorvoDevice?.blePeripheralName ?? "Unknown") timed-out removed at index \(index)")
                    logger.info("Device timestamp: \(qorvoDevice!.bleTimestamp) Current timestamp: \(timeStamp) ")
                    if qorvoDevices.indices.contains(index) {
                        qorvoDevices.remove(at: index)
                    }
                    if let didTimeoutHandler = accessoryTimeoutHandler {
                        didTimeoutHandler(deviceID!)
                    }
                }
            }
            
            index = index + 1
        }
    }
    
    // Get Qorvo device from the uniqueID
    func getDeviceFromUniqueID(_ uniqueID: Int)->qorvoDevice? {
        
        if let index = qorvoDevices.firstIndex(where: {$0?.bleUniqueID == uniqueID}) {
            return qorvoDevices[index]
        }
        else {
            return nil
        }
        
    }
    
    func start() {
        if bluetoothReady {
            startScan()
            retrievePeripheral()
        } else {
            shouldStartWhenReady = true
        }
    }

    func stop() throws {
        
    }
    
    func connectPeripheral(_ uniqueID: Int) throws {
        
        if let deviceToConnect = getDeviceFromUniqueID(uniqueID) {
            // Throw error if status is not Discovered
            if deviceToConnect.blePeripheralStatus != statusDiscovered {
                return
            }
            // Connect to the peripheral.
            logger.info("Connecting to Peripheral \(deviceToConnect.blePeripheral)")
            deviceToConnect.blePeripheralStatus = statusConnected
            centralManager.connect(deviceToConnect.blePeripheral, options: nil)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    func disconnectPeripheral(_ uniqueID: Int) throws {
        
        if let deviceToDisconnect = getDeviceFromUniqueID(uniqueID) {
            // Return if status is not Connected or Ranging
            if deviceToDisconnect.blePeripheralStatus == statusDiscovered {
                return
            }
            // Disconnect from peripheral.
            logger.info("Disconnecting from Peripheral \(deviceToDisconnect.blePeripheral)")
            centralManager.cancelPeripheralConnection(deviceToDisconnect.blePeripheral)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    func sendData(_ data: Data,_ uniqueID: Int) throws {
        let str = String(format: "Sending Data to device %d", uniqueID)
        logger.info("\(str)")
        
        if getDeviceFromUniqueID(uniqueID) != nil {
            writeData(data, uniqueID)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    // MARK: - Helper Methods.
    /*
     * BLE will be scanning for new devices, using the service's 128bit CBUUID, all the time.
     */
    private func startScan() {
        logger.info("Scanning started.")
        
        centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID, QorvoNIService.serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    /*
     * Check for a connected peer.
     */
    private func retrievePeripheral() {

    }

    /*
     * Stops an erroneous or completed connection. Note, `didUpdateNotificationStateForCharacteristic`
     * cancels the connection if a subscriber exists.
     */
    private func cleanup() {
        
    }
    
    // Sends data to the peripheral.
    private func writeData(_ data: Data,_ uniqueID: Int) {
        
        let qorvoDevice = getDeviceFromUniqueID(uniqueID)

        guard let discoveredPeripheral = qorvoDevice?.blePeripheral
        else { return }
        
        guard let transferCharacteristic = qorvoDevice?.rxCharacteristic
        else { return }
        
        logger.info("Getting TX Characteristics from device \(uniqueID).")
        
        let mtu = discoveredPeripheral.maximumWriteValueLength(for: .withResponse)

        let bytesToCopy: size_t = min(mtu, data.count)

        var rawPacket = [UInt8](repeating: 0, count: bytesToCopy)
        data.copyBytes(to: &rawPacket, count: bytesToCopy)
        let packetData = Data(bytes: &rawPacket, count: bytesToCopy)

        let stringFromData = packetData.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Writing \(bytesToCopy) bytes: \(String(describing: stringFromData))")

        discoveredPeripheral.writeValue(packetData, for: transferCharacteristic, type: .withResponse)

        writeIterationsComplete += 1
    }
}

extension DataCommunicationChannel: CBCentralManagerDelegate {
    /*
     * When Bluetooth is powered, starts Bluetooth operations.
     *
     * The protocol requires a `centralManagerDidUpdateState` implementation.
     * Ensure you can use the Central by checking whether the its state is
     * `poweredOn`. Your app can check other states to ensure availability such
     * as whether the current device supports Bluetooth LE.
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

        switch central.state {
            
        // Begin communicating with the peripheral.
        case .poweredOn:
            logger.info("CBManager is powered on")
            bluetoothReady = true
            if shouldStartWhenReady {
                start()
            }
        // In your app, deal with the following states as necessary.
        case .poweredOff:
            logger.error("CBManager is not powered on")
            return
        case .resetting:
            logger.error("CBManager is resetting")
            return
        case .unauthorized:
            handleCBUnauthorized()
            return
        case .unknown:
            logger.error("CBManager state is unknown")
            return
        case .unsupported:
            logger.error("Bluetooth is not supported on this device")
            return
        @unknown default:
            logger.error("A previously unknown central manager state occurred")
            return
        }
    }

    // Reacts to the varying causes of Bluetooth restriction.
    internal func handleCBUnauthorized() {
        switch CBManager.authorization {
        case .denied:
            // In your app, consider sending the user to Settings to change authorization.
            logger.error("The user denied Bluetooth access.")
        case .restricted:
            logger.error("Bluetooth is restricted")
        default:
            logger.error("Unexpected authorization")
        }
    }

    // Reacts to transfer service UUID discovery.
    // Consider checking the RSSI value before attempting to connect.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        //logger.info("Discovered \( String(describing: peripheral.name)) at\(RSSI.intValue)")
        
        let timeStamp = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        
        // Check if peripheral is already discovered
        if let qorvoDevice = getDeviceFromUniqueID(peripheral.hashValue) {
            
            // if yes, update the timestamp
            qorvoDevice.bleTimestamp = timeStamp
            
            return
        }
        
        // If not discovered, include peripheral to qorvoDevices[]
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        qorvoDevices.append(qorvoDevice(peripheral: peripheral,
                                        uniqueID: peripheral.hashValue,
                                        peripheralName: name ?? "Unknown",
                                        timeStamp: timeStamp))
        
        if let newPeripheral = qorvoDevices.last {
            let nameToPrint = newPeripheral?.blePeripheralName
            logger.info("Peripheral \(nameToPrint ?? "Unknown") included in qorvoDevices with unique ID")
        }
        
        if let didDiscoverHandler = accessoryDiscoveryHandler {
            didDiscoverHandler(qorvoDevices.count - 1)
        }
    }

    // Reacts to connection failure.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to \(peripheral). \( String(describing: error))")
        cleanup()
    }

    // Discovers the services and characteristics to find the 'TransferService'
    // characteristic after peripheral connection.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Peripheral Connected")

        // Set the iteration info.
        connectionIterationsComplete += 1
        writeIterationsComplete = 0

        // Set the `CBPeripheral` delegate to receive callbacks for its services discovery.
        peripheral.delegate = self

        // Search only for services that match the service UUID.
        peripheral.discoverServices([TransferService.serviceUUID, QorvoNIService.serviceUUID])
    }

    // Cleans up the local copy of the peripheral after disconnection.
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Peripheral Disconnected")
        
        let uniqueID = peripheral.hashValue
        let qorvoDevice = getDeviceFromUniqueID(uniqueID)
        
        // Update Timestamp to avoid premature disconnection
        let timeStamp = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        qorvoDevice!.bleTimestamp = timeStamp
        // Finally, update the device status
        qorvoDevice!.blePeripheralStatus = statusDiscovered
        
        if let didDisconnectHandler = accessoryDisconnectedHandler {
            didDisconnectHandler(uniqueID)
        }
        
        // Resume scanning after disconnection.
        if connectionIterationsComplete < defaultIterations {
            logger.info("Retrieve Peripheral")
            retrievePeripheral()
        } else {
            logger.info("Connection iterations completed")
        }
    }
}

// An extention to implement `CBPeripheralDelegate` methods.
extension DataCommunicationChannel: CBPeripheralDelegate {
    
    // Reacts to peripheral services invalidation.
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {

        for service in invalidatedServices where service.uuid == TransferService.serviceUUID {
            logger.error("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([TransferService.serviceUUID])
        }
        for service in invalidatedServices where service.uuid == QorvoNIService.serviceUUID {
            logger.error("Qorvo NI service is invalidated - rediscover services")
            peripheral.discoverServices([QorvoNIService.serviceUUID])
        }
    }

    // Reacts to peripheral services discovery.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }
        logger.info("discovered service. Now discovering characteristics")
        // Check the newly filled peripheral services array for more services.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([TransferService.rxCharacteristicUUID,
                                                TransferService.txCharacteristicUUID,
                                                QorvoNIService.rxCharacteristicUUID,
                                                QorvoNIService.txCharacteristicUUID], for: service)
        }
    }

    // Subscribes to a discovered characteristic, which lets the peripheral know we want the data it contains.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }

        let uniqueID = peripheral.hashValue
        let qorvoDevice = getDeviceFromUniqueID(uniqueID)
        
        // Check the newly filled peripheral services array for more services.
        guard let serviceCharacteristics = service.characteristics else { return }
        
        // Assign RX Characteristic to the device structure
        for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.rxCharacteristicUUID {
            // Subscribe to the transfer service's `rxCharacteristic`.
            qorvoDevice?.rxCharacteristic = characteristic
            logger.info("discovered characteristic: \(characteristic)")
        }
        for characteristic in serviceCharacteristics where characteristic.uuid == QorvoNIService.rxCharacteristicUUID {
            // Subscribe to the transfer service's `rxCharacteristic`.
            qorvoDevice?.rxCharacteristic = characteristic
            logger.info("discovered characteristic: \(characteristic)")
        }
        
        // Assign TX Characteristic to the device structure
        for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.txCharacteristicUUID {
            // Subscribe to the transfer service's `txCharacteristic`.
            qorvoDevice?.txCharacteristic = characteristic
            logger.info("discovered characteristic: \(characteristic)")
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        for characteristic in serviceCharacteristics where characteristic.uuid == QorvoNIService.txCharacteristicUUID {
            // Subscribe to the transfer service's `txCharacteristic`.
            qorvoDevice?.txCharacteristic = characteristic
            logger.info("discovered characteristic: \(characteristic)")
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Wait for the peripheral to send data.
        if let didConnectHandler = accessoryConnectedHandler {
            didConnectHandler(peripheral.hashValue)
        }
    }

    // Reacts to data arrival through the characteristic notification.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Check if the peripheral reported an error.
        if let error = error {
            logger.error("Error discovering characteristics:\(error.localizedDescription)")
            cleanup()
            
            return
        }
        guard let characteristicData = characteristic.value else { return }
    
        let str = characteristicData.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Received \(characteristicData.count) bytes: \(str)")
        
        let uniqueID = peripheral.hashValue
        let qorvoDevice = getDeviceFromUniqueID(uniqueID)
        
        if let dataHandler = self.accessoryDataHandler, let accessoryName = qorvoDevice?.blePeripheralName {
            dataHandler(characteristicData, accessoryName, uniqueID)
        }
    }

    // Reacts to the subscription status.
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Check if the peripheral reported an error.
        if let error = error {
            logger.error("Error changing notification state: \(error.localizedDescription)")
            return
        }

        if characteristic.isNotifying {
            // Indicates the notification began.
            logger.info("Notification began on \(characteristic)")
        } else {
            // Because the notification stopped, disconnect from the peripheral.
            logger.info("Notification stopped on \(characteristic). Disconnecting")
            cleanup()
        }
    }
}
