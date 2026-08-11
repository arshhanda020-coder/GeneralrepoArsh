//
//  NoteContext.swift
//  Odysseus
//
//  Where a note lives. A note isn't locked to the standalone Notes hub — it
//  can be pinned to Today as a quick reminder, or attached to a Project,
//  School topic, or Subagent so it shows up right there too. `nil` means
//  standalone (only visible in the Notes hub).
//

import Foundation
import SwiftData

enum NoteContext: Equatable, Hashable {
    case today
    case project(String)
    case topic(String)
    case agentDefinition(String)

    var typeRaw: String {
        switch self {
        case .today: return "today"
        case .project: return "project"
        case .topic: return "topic"
        case .agentDefinition: return "agentDefinition"
        }
    }

    /// The linked record's id, or nil for `.today` (which isn't tied to one record).
    var recordID: String? {
        switch self {
        case .today: return nil
        case .project(let id), .topic(let id), .agentDefinition(let id):
            return id
        }
    }

    static func from(typeRaw: String?, id: String?) -> NoteContext? {
        switch typeRaw {
        case "today": return .today
        case "project": return id.map(NoteContext.project)
        case "topic": return id.map(NoteContext.topic)
        case "agentDefinition": return id.map(NoteContext.agentDefinition)
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .today: return "Today"
        case .project: return "Project"
        case .topic: return "School"
        case .agentDefinition: return "Workflow"
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "checkmark.seal"
        case .project: return "hammer"
        case .topic: return "graduationcap.fill"
        case .agentDefinition: return "cpu"
        }
    }

    /// Looks up the human-readable name of the linked record, e.g. the
    /// project's name or topic's name. Nil if the record's since been
    /// deleted (the note just shows its generic label then).
    func resolvedName(in modelContext: ModelContext) -> String? {
        switch self {
        case .today:
            return "Today"
        case .project(let id):
            return (try? modelContext.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })))?.first?.name
        case .topic(let id):
            return (try? modelContext.fetch(FetchDescriptor<Topic>(predicate: #Predicate { $0.id == id })))?.first?.name
        case .agentDefinition(let id):
            return (try? modelContext.fetch(FetchDescriptor<AgentDefinition>(predicate: #Predicate { $0.id == id })))?.first?.name
        }
    }
}

/// Shared by every note-like model (`Note`, `DocNote`) so they can all be
/// created, moved, and displayed through the same UI.
protocol NoteContextLinkable: AnyObject {
    var contextTypeRaw: String? { get set }
    var contextID: String? { get set }
}

extension NoteContextLinkable {
    var context: NoteContext? {
        get { NoteContext.from(typeRaw: contextTypeRaw, id: contextID) }
        set {
            contextTypeRaw = newValue?.typeRaw
            contextID = newValue?.recordID
        }
    }
}
