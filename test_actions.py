#!/usr/bin/env python3
"""Test script for action item extraction."""

import requests
import time
import json

BASE_URL = "http://localhost:8000"

test_cases = [
    {
        "content": "need to call john about the project",
        "expected_actions": ["call john about the project"],
        "expected_indicator": "[!1]"
    },
    {
        "content": "feeling tired today #work",
        "expected_actions": [],
        "expected_indicator": None
    },
    {
        "content": "todo: fix css bug and review PR",
        "expected_actions": ["fix css bug", "review PR"],
        "expected_indicator": "[!2]"
    },
    {
        "content": "must fix the broken test cases tomorrow",
        "expected_actions": ["fix the broken test cases tomorrow"],
        "expected_indicator": "[!1]"
    },
    {
        "content": "have to update documentation before release",
        "expected_actions": ["update documentation before release"],
        "expected_indicator": "[!1]"
    }
]

def create_entry(content):
    """Create a new entry and return its HTML."""
    response = requests.post(
        f"{BASE_URL}/entries",
        data={"content": content}
    )
    return response.text

def main():
    print("Testing action item extraction...")
    print("-" * 50)

    for i, test in enumerate(test_cases, 1):
        print(f"\nTest {i}: {test['content']}")

        # Create entry
        html = create_entry(test["content"])

        # Wait for background processing
        print("  Waiting for LLM processing...")
        time.sleep(3)

        # Get all entries to check the processed result
        response = requests.get(f"{BASE_URL}/entries")
        entries_html = response.text

        # Check if expected indicator appears
        if test["expected_indicator"]:
            if test["expected_indicator"] in entries_html:
                print(f"  ✓ Found expected indicator: {test['expected_indicator']}")
            else:
                print(f"  ✗ Missing expected indicator: {test['expected_indicator']}")
        else:
            if "[!" in entries_html and test["content"] in entries_html:
                print(f"  ✗ Unexpected action indicator found")
            else:
                print(f"  ✓ No action indicator (as expected)")

        print(f"  Expected actions: {test['expected_actions']}")

if __name__ == "__main__":
    main()