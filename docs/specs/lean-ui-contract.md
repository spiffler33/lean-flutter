# Lean UI Contract

## Architecture Overview
- **Structure**: Module pattern with LeanApp namespace
- **State Management**: Centralized state object
- **Event Handling**: KEYS object for keyboard shortcuts
- **Components**: Isolated UI components with clear responsibilities

## Core Components

### LeanApp (Main Module)
**Purpose**: Central application controller
**Methods**:
- `init()`: Initialize app on DOM ready
- `toggleTodo(entryId)`: Toggle todo checkbox state
- `toggleTodoFilter()`: Filter/unfilter todo entries
- `searchTag(tag)`: Search entries by tag
- Modal control methods for stats and export

### TimeDivider Component
**Purpose**: Shows time gaps between writing sessions (>2 hours)
**Methods**:
- `insert()`: Add divider for new sessions
- `insertForClear()`: Add divider after /clear command
- `formatDividerText()`: Format human-readable time text
- `createDividerElement()`: Build DOM element

### Toast Component
**Purpose**: Temporary notification system (unused but available)
**Methods**:
- `show(message, duration)`: Display temporary message

### CommandHandlers
**Purpose**: Process slash commands
**Commands**:
- `/search`, `/today`, `/yesterday`, `/week`: Search/filter
- `/clear`: Clear view (preserves time divider)
- `/stats`, `/export`: Open modals
- `/help`: Show command reference
- `/essay`, `/idea`: Insert templates
- `/theme`: Switch visual themes
- `/ai sum`: Generate AI summary

## DOM Elements Cache
**Cached on init**:
- `input`: Main textarea
- `form`: HTMX submission form
- `entries`: Entry container
- `charCounter`: Character counter
- `draftIndicator`: Draft save indicator
- `todoCounter`: Todo count badge

## Keyboard Shortcuts (KEYS object)
- `Enter`: Submit entry
- `Shift+Enter`: New line
- `ArrowUp`: Edit last entry
- `Escape`: Clear input/close overlays
- `/`: Jump to input field

## State Management
```javascript
state = {
    editingEntryId: null,       // ID of entry being edited
    draftTimer: null,          // Auto-save timer
    currentTheme: 'minimal',   // Active theme
    todoFilterActive: false,   // Todo filter state
    currentExportFormat: 'markdown'  // Export format
}
```

## Entry Lifecycle
1. **Create**: Optimistic UI → Backend save → Replace temp
2. **Edit**: Load content → Update → Replace DOM
3. **Todo Toggle**: Update checkbox → Backend sync → Counter update

## Performance Optimizations
- Critical CSS inline (<100ms first paint)
- Non-critical CSS async loaded
- Optimistic UI for instant feedback
- Debounced draft saving
- Single observer for entry changes

## Event Flow
1. User types → Auto-resize → Character count → Draft timer
2. Enter key → Command check → Create/Update entry
3. Todo click → Toggle state → Backend update → Counter refresh

## Data Flow
- **Input → State**: User actions update local state
- **State → Backend**: HTMX/fetch for persistence
- **Backend → DOM**: HTML responses update entries
- **DOM → State**: Observers sync counters/timestamps

## CSS Organization
- **Inline**: Critical above-fold styles (180 lines)
- **lean.css**: Themes, animations, modals, utilities (850 lines)
- **Total**: ~1030 lines CSS (vs 1326 original)

## JavaScript Organization
- **Single namespace**: LeanApp module
- **Component pattern**: TimeDivider, Toast isolated
- **Handler groups**: CommandHandlers object
- **Total**: ~1070 lines JS (vs 1270 original)

## Final Metrics
- **index.html**: 1338 lines (down from 2691)
- **Reduction**: 50% smaller, better organized
- **Load time**: <100ms critical render path
- **Maintainability**: Clear component boundaries