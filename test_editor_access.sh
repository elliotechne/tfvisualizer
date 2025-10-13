#!/bin/bash

# Test Editor Access Protection
# This script tests that the editor cannot be accessed without authentication

echo "=========================================="
echo "Testing Editor Access Protection"
echo "=========================================="
echo ""

BASE_URL="${BASE_URL:-http://localhost:80}"

echo "Test 1: Access /editor without authentication"
echo "----------------------------------------------"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L "$BASE_URL/editor")
if [ "$RESPONSE" -eq 200 ]; then
    # Check if it's the login page
    CONTENT=$(curl -s -L "$BASE_URL/editor")
    if echo "$CONTENT" | grep -q "login"; then
        echo "✅ PASS: Redirected to login page"
    else
        echo "❌ FAIL: Got 200 but not login page"
    fi
else
    echo "Response code: $RESPONSE"
    if [ "$RESPONSE" -eq 302 ] || [ "$RESPONSE" -eq 301 ]; then
        echo "✅ PASS: Redirected (code $RESPONSE)"
    else
        echo "⚠️  UNEXPECTED: Got response code $RESPONSE"
    fi
fi
echo ""

echo "Test 2: Access /editor.html without authentication"
echo "---------------------------------------------------"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L "$BASE_URL/editor.html")
if [ "$RESPONSE" -eq 200 ]; then
    CONTENT=$(curl -s -L "$BASE_URL/editor.html")
    if echo "$CONTENT" | grep -q "login"; then
        echo "✅ PASS: Redirected to login page"
    else
        echo "❌ FAIL: Got 200 but not login page"
    fi
else
    echo "Response code: $RESPONSE"
    if [ "$RESPONSE" -eq 302 ] || [ "$RESPONSE" -eq 301 ]; then
        echo "✅ PASS: Redirected (code $RESPONSE)"
    else
        echo "⚠️  UNEXPECTED: Got response code $RESPONSE"
    fi
fi
echo ""

echo "Test 3: Register new user and get cookies"
echo "------------------------------------------"
EMAIL="test_$(date +%s)@example.com"
REGISTER_RESPONSE=$(curl -s -c /tmp/cookies.txt \
  -X POST "$BASE_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test User\",\"email\":\"$EMAIL\",\"password\":\"password123\"}")

if echo "$REGISTER_RESPONSE" | grep -q "success"; then
    echo "✅ PASS: User registered successfully"
    echo "Email: $EMAIL"
else
    echo "❌ FAIL: Registration failed"
    echo "$REGISTER_RESPONSE"
fi
echo ""

echo "Test 4: Access /editor with valid authentication cookie"
echo "--------------------------------------------------------"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b /tmp/cookies.txt "$BASE_URL/editor")
if [ "$RESPONSE" -eq 200 ]; then
    CONTENT=$(curl -s -b /tmp/cookies.txt "$BASE_URL/editor")
    if echo "$CONTENT" | grep -q "TF Visualizer"; then
        echo "✅ PASS: Editor page loaded successfully"
    else
        echo "❌ FAIL: Got 200 but content doesn't match editor"
    fi
else
    echo "❌ FAIL: Got response code $RESPONSE (expected 200)"
fi
echo ""

echo "Test 5: Access /editor.html with valid authentication cookie"
echo "-------------------------------------------------------------"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b /tmp/cookies.txt "$BASE_URL/editor.html")
if [ "$RESPONSE" -eq 200 ]; then
    CONTENT=$(curl -s -b /tmp/cookies.txt "$BASE_URL/editor.html")
    if echo "$CONTENT" | grep -q "TF Visualizer"; then
        echo "✅ PASS: Editor page loaded successfully"
    else
        echo "❌ FAIL: Got 200 but content doesn't match editor"
    fi
else
    echo "❌ FAIL: Got response code $RESPONSE (expected 200)"
fi
echo ""

echo "Test 6: Logout and verify editor is inaccessible"
echo "-------------------------------------------------"
curl -s -X POST "$BASE_URL/api/auth/logout" \
  -b /tmp/cookies.txt \
  -c /tmp/cookies.txt > /dev/null

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L -b /tmp/cookies.txt "$BASE_URL/editor")
if [ "$RESPONSE" -eq 200 ]; then
    CONTENT=$(curl -s -L -b /tmp/cookies.txt "$BASE_URL/editor")
    if echo "$CONTENT" | grep -q "login"; then
        echo "✅ PASS: Redirected to login after logout"
    else
        echo "❌ FAIL: Got 200 but not login page after logout"
    fi
else
    if [ "$RESPONSE" -eq 302 ] || [ "$RESPONSE" -eq 301 ]; then
        echo "✅ PASS: Redirected after logout (code $RESPONSE)"
    else
        echo "⚠️  UNEXPECTED: Got response code $RESPONSE"
    fi
fi
echo ""

# Cleanup
rm -f /tmp/cookies.txt

echo "=========================================="
echo "Testing Complete"
echo "=========================================="
