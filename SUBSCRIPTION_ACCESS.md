# Subscription Access Control

Documentation for subscription-based access to TFVisualizer features.

---

## Overview

TFVisualizer uses a subscription-based access model with two tiers:
- **Free Tier**: Limited features, automatically activated on registration
- **Professional Tier**: Full features, $4.99/month via Stripe

---

## Editor Access Requirements

### Protected Routes

The **Terraform Visual Editor** (`/editor`, `/editor.html`) requires:

1. **Authentication**: User must be logged in with valid JWT token
2. **Active Subscription**: User must have an active subscription (free or pro)

### Access Flow

```
User visits /editor
    ↓
Check JWT token (authentication)
    ↓
    ├─ No token → Redirect to /login
    │
    └─ Token valid
        ↓
        Check subscription_status
            ↓
            ├─ status = 'active' or 'trialing' → Grant access ✅
            │
            └─ status = 'inactive' or 'canceled' → Redirect to /pricing ❌
```

---

## Subscription Statuses

| Status | Description | Editor Access |
|--------|-------------|---------------|
| `active` | Free or Pro tier active | ✅ Yes |
| `trialing` | Pro tier trial period | ✅ Yes |
| `inactive` | No active subscription | ❌ No |
| `canceled` | Subscription canceled | ❌ No |

---

## User Registration Flow

When a new user registers:

1. User account created
2. `subscription_tier` = `'free'`
3. `subscription_status` = `'active'`
4. **Immediate editor access granted**

### Code Reference

`app/routes/auth.py:50-57`

```python
# Create new user with free tier active by default
user = User(name=name, email=email)
user.set_password(password)
user.subscription_tier = 'free'
user.subscription_status = 'active'  # Free tier is active by default
```

---

## Upgrading to Professional

When a user upgrades to Pro via Stripe:

1. User clicks "Subscribe" on `/pricing`
2. Stripe Checkout session created
3. User completes payment
4. Webhook updates user:
   - `subscription_tier` = `'pro'`
   - `subscription_status` = `'active'`
5. Unlimited projects and advanced features enabled

---

## Free Tier Limitations

Free tier users have access to the editor but with limitations:

- **Project Limit**: Maximum projects defined in `Config.FREE_TIER_PROJECT_LIMIT`
- **All core features**: Visual editor, Terraform code generation, import/export

### Checking Project Limits

`app/models/user.py:44-53`

```python
def can_create_project(self) -> bool:
    """Check if user can create more projects based on their tier"""
    from app.config.settings import Config

    if self.subscription_tier == 'pro':
        return True  # Unlimited for Pro tier

    # Free tier has a limit
    project_count = self.projects.count()
    return project_count < Config.FREE_TIER_PROJECT_LIMIT
```

---

## Professional Tier Benefits

Pro tier users (`subscription_tier = 'pro'`, `subscription_status = 'active'`):

- ✅ Unlimited projects
- ✅ Priority support
- ✅ Advanced features (future)
- ✅ Team collaboration (future)
- ✅ Private modules (future)

---

## Testing Access Control

### Test Free Tier Access

```bash
# Register new user (auto-activates free tier and sets cookies)
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"password123"}' \
  -c cookies.txt

# Access editor using cookies (should work)
curl -b cookies.txt http://localhost/editor

# Or use header-based authentication
export TOKEN="<access_token_from_response>"
curl http://localhost/editor \
  -H "Authorization: Bearer $TOKEN"
```

### Test Inactive Subscription Block

```bash
# Manually set subscription_status to 'inactive' in database
# Then try to access editor

curl http://localhost/editor \
  -H "Authorization: Bearer $TOKEN"

# Should redirect to /pricing
```

---

## Implementation Files

| File | Purpose |
|------|---------|
| `app/routes/pages.py` | Editor route with `@jwt_required()` decorator and subscription check |
| `app/routes/auth.py` | Auto-activates free tier on registration |
| `app/models/user.py` | User model with subscription fields and `can_create_project()` method |
| `app/services/stripe_service.py` | Handles Stripe webhooks and subscription updates |

---

## Security Notes

### Authentication

- JWT tokens required for editor access
- Tokens stored in **both** HTTP-only cookies and response body
- Cookie-based authentication for browser page routes (like `/editor`)
- Header-based authentication for API routes (like `/api/projects`)
- Token expiration enforced by Flask-JWT-Extended
- Tokens automatically included in browser requests via cookies

### Authorization

- Subscription status checked on every editor page load
- Status can be changed via:
  - Stripe webhook (payment success/failure)
  - Admin action (future)
  - Subscription cancellation

### Best Practices

✅ **DO:**
- Always check both authentication (JWT) and authorization (subscription status)
- Redirect unauthenticated users to login
- Redirect unauthorized users to pricing page
- Auto-activate free tier on registration

❌ **DON'T:**
- Grant editor access without subscription check
- Store subscription status in JWT (use database as source of truth)
- Allow inactive subscriptions to access editor

---

## Future Enhancements

### Planned Features

1. **Trial Period**: 14-day free trial of Pro features
2. **Usage Tracking**: Monitor API calls and resource usage
3. **Team Subscriptions**: Multi-user Pro accounts
4. **Feature Flags**: Granular feature control per tier
5. **Metered Billing**: Pay-per-use for high-volume users

### Feature Flags Example

```python
# Future implementation
def has_feature(user, feature_name):
    """Check if user has access to a specific feature"""
    FEATURE_MATRIX = {
        'free': ['editor', 'basic_export'],
        'pro': ['editor', 'basic_export', 'advanced_modules', 'team_collab']
    }
    return feature_name in FEATURE_MATRIX.get(user.subscription_tier, [])
```

---

## Troubleshooting

### User Can't Access Editor After Registration

**Check:**
1. `subscription_status` is `'active'` (not `'inactive'`)
2. JWT token is valid and not expired
3. User exists in database

**Fix:**
```sql
UPDATE users SET subscription_status = 'active' WHERE email = 'user@example.com';
```

### Free Tier User Can't Create Projects

**Check:**
1. Project count vs `Config.FREE_TIER_PROJECT_LIMIT`
2. `user.can_create_project()` returns `True`

**Fix:**
- Upgrade to Pro tier, or
- Delete old projects to free up slots

### Pro User Still Seeing Limits

**Check:**
1. `subscription_tier` is `'pro'` (not `'free'`)
2. `subscription_status` is `'active'`
3. Stripe webhook processed successfully

**Fix:**
```sql
UPDATE users
SET subscription_tier = 'pro', subscription_status = 'active'
WHERE stripe_customer_id = 'cus_xxxxx';
```

---

## Related Documentation

- [GITHUB_SECRETS_SETUP.md](GITHUB_SECRETS_SETUP.md) - Stripe API keys configuration
- [INFRASTRUCTURE_AS_CODE.md](INFRASTRUCTURE_AS_CODE.md) - Infrastructure overview
- [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md) - Database schema and operations

---

**Editor access is now protected. All new users get free tier access automatically.**
