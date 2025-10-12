# Core Functionality Tests

Before ANY change is considered complete:

1. Entry Creation
   - Type "test" → Enter → Saves in <100ms
   - Type "[] todo" → Enter → Shows checkbox

2. Todo Counter
   - Create todo → Counter shows "☐ 1"
   - Click counter → Shows only todos
   - Run /clear → Click counter → STILL WORKS

3. Commands
   - /essay → Full template appears
   - /clear → Entries gone, UI elements remain
   - /today → Shows today's entries only

4. Time Divider
   - Appears if away >2 hours
   - Persists through /clear
   - Not saved as entry
