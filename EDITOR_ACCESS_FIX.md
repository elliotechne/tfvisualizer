# Editor Access Fix - Cookie-Based Authentication

## Problem

Users could access `/editor.html` directly without logging in, bypassing authentication.

## Root Cause

The JWT configuration only supported header-based authentication (`Authorization: Bearer <token>`), but browser page requests don't automatically include these headers. The `@jwt_required()` decorator was raising exceptions instead of redirecting unauthenticated users.

## Solution

Implemented **dual authentication** supporting both cookies and headers:

### 1. Updated JWT Configuration

**File:** `app/config/settings.py`

```python
# Before
JWT_TOKEN_LOCATION = ['headers']

# After
JWT_TOKEN_LOCATION = ['headers', 'cookies']
JWT_COOKIE_SECURE = False  # True in production with HTTPS
JWT_COOKIE_CSRF_PROTECT = False  # True in production
JWT_COOKIE_SAMESITE = 'Lax'
```

### 2. Updated Authentication Endpoints

**File:** `app/routes/auth.py`

#### Registration & Login
Now set JWT tokens in **both** response body and HTTP-only cookies:

```python
from flask_jwt_extended import set_access_cookies, set_refresh_cookies

# Create response
response = jsonify({
    'success': True,
    'access_token': access_token,
    'refresh_token': refresh_token,
    'user': user.to_dict()
})

# Set cookies for browser authentication
set_access_cookies(response, access_token)
set_refresh_cookies(response, refresh_token)

return response
```

#### Logout
Clear JWT cookies:

```python
from flask_jwt_extended import unset_jwt_cookies

response = jsonify({'success': True, 'message': 'Logout successful'})
unset_jwt_cookies(response)
return response
```

### 3. Updated Editor Route

**File:** `app/routes/pages.py`

```python
@bp.route('/editor')
@bp.route('/editor.html')
def editor():
    """Requires authentication and active subscription"""
    from flask import redirect, url_for, flash
    from flask_jwt_extended import verify_jwt_in_request

    # Check JWT token (from cookies or headers)
    try:
        verify_jwt_in_request()
        user_id = get_jwt_identity()
    except Exception:
        flash('Please log in to access the editor', 'error')
        return redirect(url_for('pages.login_page'))

    # Get user and check subscription
    user = User.query.get(user_id)
    if not user:
        return redirect(url_for('pages.login_page'))

    if user.subscription_status not in ['active', 'trialing']:
        flash('Please subscribe to a plan', 'warning')
        return redirect(url_for('pages.pricing'))

    return render_template('editor.html', user=user)
```

---

## How It Works

### Authentication Flow

```
1. User registers/logs in
   ↓
2. Server generates JWT access & refresh tokens
   ↓
3. Server sets tokens in:
   - HTTP-only cookies (for browser)
   - Response body (for mobile/API clients)
   ↓
4. Browser automatically includes cookies in subsequent requests
   ↓
5. Server validates token from cookie or Authorization header
   ↓
6. Access granted or redirect to login
```

### Token Storage

| Client Type | Storage Method | Location |
|-------------|----------------|----------|
| Browser | HTTP-only Cookie | `access_token_cookie` |
| Mobile App | localStorage/SecureStorage | App storage |
| API Client | Environment Variable | Headers |

---

## Testing

### Test 1: Direct Access Without Login

```bash
# Should redirect to login
curl -L http://localhost/editor

# Expected: Redirect to /login
```

### Test 2: Access After Login

```bash
# Login and save cookies
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}' \
  -c cookies.txt

# Access editor with cookies
curl -b cookies.txt http://localhost/editor

# Expected: Editor HTML page
```

### Test 3: Access with Inactive Subscription

```sql
-- Set subscription to inactive
UPDATE users SET subscription_status = 'inactive' WHERE email = 'user@example.com';
```

```bash
# Try to access editor
curl -b cookies.txt -L http://localhost/editor

# Expected: Redirect to /pricing
```

### Test 4: Logout Clears Cookies

```bash
# Logout
curl -X POST http://localhost/api/auth/logout \
  -b cookies.txt \
  -c cookies.txt

# Try to access editor
curl -b cookies.txt -L http://localhost/editor

# Expected: Redirect to /login (cookies cleared)
```

---

## Security Benefits

### HTTP-Only Cookies
- ✅ Not accessible via JavaScript (prevents XSS attacks)
- ✅ Automatically included in browser requests
- ✅ Can be marked Secure (HTTPS-only) in production

### Production Security

In production (`ProductionConfig`):

```python
JWT_COOKIE_SECURE = True        # Require HTTPS
JWT_COOKIE_CSRF_PROTECT = True  # Enable CSRF protection
```

### Token Expiration

- **Access Token**: 1 hour (`JWT_ACCESS_TOKEN_EXPIRES`)
- **Refresh Token**: 30 days (`JWT_REFRESH_TOKEN_EXPIRES`)

---

## Development vs Production

| Setting | Development | Production |
|---------|-------------|------------|
| `JWT_COOKIE_SECURE` | False (HTTP allowed) | True (HTTPS required) |
| `JWT_COOKIE_CSRF_PROTECT` | False | True |
| `DEBUG` | True | False |

---

## Files Modified

| File | Changes |
|------|---------|
| `app/config/settings.py` | Added cookie support to JWT configuration |
| `app/routes/auth.py` | Set tokens in cookies on login/register, clear on logout |
| `app/routes/pages.py` | Use `verify_jwt_in_request()` with try/except for proper redirects |
| `SUBSCRIPTION_ACCESS.md` | Updated documentation with cookie authentication details |

---

## Verification Checklist

- [x] JWT tokens stored in HTTP-only cookies
- [x] Tokens also returned in response body (for API clients)
- [x] `/editor` route redirects unauthenticated users to `/login`
- [x] `/editor` route redirects users without active subscription to `/pricing`
- [x] New users automatically get free tier with `active` status
- [x] Logout clears JWT cookies
- [x] Production config enforces HTTPS and CSRF protection

---

## Next Steps

### For Production Deployment

1. **Enable HTTPS**: Ensure SSL/TLS certificate is configured
2. **Update Environment Variables**:
   ```bash
   export FLASK_ENV=production
   export JWT_SECRET=<strong-random-secret>
   ```
3. **Verify Cookies**:
   - Check cookies are marked `Secure` in production
   - Verify `SameSite=Lax` policy

### For Frontend Integration

If you have a login page UI:

```javascript
// Login function
async function login(email, password) {
  const response = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
    credentials: 'include'  // Important: include cookies
  });

  const data = await response.json();
  if (data.success) {
    // Cookies automatically set, redirect to editor
    window.location.href = '/editor';
  }
}

// Logout function
async function logout() {
  await fetch('/api/auth/logout', {
    method: 'POST',
    credentials: 'include'  // Important: include cookies
  });

  // Cookies cleared, redirect to home
  window.location.href = '/';
}
```

---

## Troubleshooting

### Issue: Still can access /editor without login

**Check:**
1. Are you using a cached browser session?
   - Solution: Clear browser cookies and cache
2. Is Flask using the correct config?
   - Solution: Verify `FLASK_ENV` environment variable
3. Are cookies being set?
   - Solution: Check browser DevTools → Application → Cookies

### Issue: Redirect loop between /editor and /login

**Check:**
1. Is `subscription_status` set to 'active'?
   ```sql
   SELECT email, subscription_status FROM users;
   ```
2. Are cookies being sent with the request?
   - Solution: Check `credentials: 'include'` in fetch calls

### Issue: Works in development, fails in production

**Check:**
1. HTTPS enabled? (Required for `JWT_COOKIE_SECURE = True`)
2. Correct domain for cookies?
3. CORS settings allowing credentials?

---

**Editor access is now fully protected with cookie-based authentication. ✅**
