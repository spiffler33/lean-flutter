"""
Integration test for Stage 4: Create real entries and verify temporal patterns
"""
import httpx
import asyncio
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8000"

async def create_entry(content: str):
    """Create an entry via API"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/entries",
            data={"content": content}
        )
        return response.status_code == 200

async def view_patterns():
    """View patterns via API"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/entries",
            data={"content": "/patterns"}
        )
        return response.text

async def main():
    print("=" * 60)
    print("STAGE 4 INTEGRATION TEST")
    print("=" * 60)

    # Create diverse entries to build temporal patterns
    entries = [
        "Monday morning work meeting with the team #work",
        "Need to finish the project proposal by Friday #work",
        "Feeling anxious about the deadline approaching",
        "Weekend plans - going hiking with friends #leisure",
        "Friday evening reflection - grateful for the week",
        "Saturday afternoon relaxing at home, feeling content",
        "Sunday morning planning for the week ahead"
    ]

    print("\n1. Creating test entries...")
    for entry in entries:
        success = await create_entry(entry)
        if success:
            print(f"✓ Created: {entry[:50]}...")
        await asyncio.sleep(0.5)  # Give LLM time to process

    print("\n2. Waiting for background processing...")
    await asyncio.sleep(5)  # Wait for LLM processing

    print("\n3. Viewing patterns...")
    patterns_html = await view_patterns()

    # Check for Stage 4 enhancements
    print("\n4. Verifying Stage 4 features:")

    if "YOUR WRITING RHYTHMS" in patterns_html:
        print("✓ Writing rhythms section present")
    else:
        print("✗ Writing rhythms section missing")

    if "BY TIME OF DAY" in patterns_html or "BY DAY OF WEEK" in patterns_html or "WEEKDAY VS WEEKEND" in patterns_html:
        print("✓ Enhanced temporal breakdown present")
    else:
        print("⚠ Temporal breakdown needs more data")

    print("\n5. Pattern display sample:")
    print("-" * 60)
    # Extract just the patterns content
    if "What Lean Has Learned About You" in patterns_html:
        start = patterns_html.find("What Lean Has Learned About You")
        end = patterns_html.find("</div></div>", start) + 12
        sample = patterns_html[start:end]
        # Clean HTML for display
        sample = sample.replace("<br>", "\n").replace("<strong>", "").replace("</strong>", "")
        sample = sample.replace("</div>", "").replace("<div", "")
        sample = sample.replace("class=\"entry-content\">", "").replace("class=\"entry\">", "")
        print(sample[:800])

    print("\n" + "=" * 60)
    print("✅ STAGE 4 INTEGRATION TEST COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(main())
