//
//  HotkeyCenter.swift
//  STATIONS
//
//  Registers each station's global hotkey with Carbon and fires activation
//  when one is pressed. Registrations follow the store: any change to the
//  stations list re-registers everything.
//

import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()
    private init() {}

    private var handlerInstalled = false
    private var registrations: [EventHotKeyRef] = []
    private var stationIDsByHotkeyID: [UInt32: UUID] = [:]
    private var nextHotkeyID: UInt32 = 1
    private var subscription: AnyCancellable?

    func bootstrap() {
        installHandlerIfNeeded()
        apply(StationStore.shared.stations)
        subscription = StationStore.shared.$stations.sink { [weak self] stations in
            self?.apply(stations)
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotkeyEventHandler, 1, &eventType, nil, nil)
        handlerInstalled = true
    }

    private func apply(_ stations: [Station]) {
        for registration in registrations {
            UnregisterEventHotKey(registration)
        }
        registrations.removeAll()
        stationIDsByHotkeyID.removeAll()

        for station in stations {
            guard let hotkey = station.hotkey else { continue }
            let hotkeyID = nextHotkeyID
            nextHotkeyID += 1

            var registration: EventHotKeyRef?
            let identity = EventHotKeyID(signature: 0x5354_4154 /* STAT */, id: hotkeyID)
            let status = RegisterEventHotKey(
                UInt32(hotkey.keyCode),
                hotkey.carbonModifiers,
                identity,
                GetApplicationEventTarget(),
                0,
                &registration
            )
            // A conflict with another app's hotkey just fails; the station
            // stays activatable from the menu.
            if status == noErr, let registration {
                registrations.append(registration)
                stationIDsByHotkeyID[hotkeyID] = station.id
            }
        }
    }

    fileprivate func fire(hotkeyID: UInt32) {
        guard let stationID = stationIDsByHotkeyID[hotkeyID],
              let station = StationStore.shared.stations.first(where: { $0.id == stationID }) else {
            return
        }
        Task {
            await StationActivator.shared.activate(station)
        }
    }
}

private nonisolated let hotkeyEventHandler: EventHandlerUPP = { _, event, _ in
    var identity = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identity
    )
    let hotkeyID = identity.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            HotkeyCenter.shared.fire(hotkeyID: hotkeyID)
        }
    }
    return noErr
}
