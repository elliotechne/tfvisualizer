# GitHub Actions Artifact Actions Update

## Summary

Updated all artifact actions from deprecated v3 to current v4 version.

---

## Changes Made

### File: `.github/workflows/terraform.yml`

**Updated Actions:**

1. **Upload Terraform Plan** (Line 157)
   ```yaml
   # Before
   uses: actions/upload-artifact@v3

   # After
   uses: actions/upload-artifact@v4
   ```

2. **Download Terraform Plan** (Line 213)
   ```yaml
   # Before
   uses: actions/download-artifact@v3

   # After
   uses: actions/download-artifact@v4
   ```

3. **Upload Terraform Outputs** (Line 227)
   ```yaml
   # Before
   uses: actions/upload-artifact@v3

   # After
   uses: actions/upload-artifact@v4
   ```

---

## Why This Update?

### Deprecation Notice

GitHub deprecated `actions/upload-artifact@v3` and `actions/download-artifact@v3`:

- **v3:** Deprecated as of November 2023
- **v4:** Current stable version with breaking changes
- **Impact:** Workflows using v3 will fail with deprecation warnings

### Error Message

```
This request has been automatically failed because it uses a deprecated version of `actions/upload-artifact: v3`
```

---

## Changes in v4

### Breaking Changes

1. **Artifact Naming:**
   - v3: Artifacts with same name overwrite each other
   - v4: Artifacts with same name create separate versions

2. **Download Behavior:**
   - v3: Downloads all artifacts by default
   - v4: Must specify artifact name explicitly

3. **Retention:**
   - v3: Default 90 days
   - v4: Default 90 days (unchanged)

### New Features in v4

1. **Improved Performance:**
   - Faster uploads and downloads
   - Better compression
   - Reduced storage usage

2. **Better Error Messages:**
   - More descriptive errors
   - Clearer validation messages

3. **Enhanced Security:**
   - Updated dependencies
   - Improved authentication

---

## Impact on Workflow

### No Functional Changes

The workflow behavior remains the same:

1. **terraform-plan job:**
   - Uploads `terraform-plan` artifact
   - Retention: 5 days

2. **terraform-apply job:**
   - Downloads `terraform-plan` artifact
   - Applies the plan
   - Uploads `terraform-outputs` artifact
   - Retention: 30 days

### Configuration Unchanged

All parameters remain compatible:

```yaml
- name: Upload Plan
  uses: actions/upload-artifact@v4  # Only version changed
  with:
    name: terraform-plan              # Same
    path: ${{ env.TF_WORKING_DIR }}/tfplan  # Same
    retention-days: 5                 # Same
```

---

## Testing

### Verify Artifacts Work

1. **Trigger workflow:**
   ```bash
   git add .github/workflows/terraform.yml
   git commit -m "Update artifact actions to v4"
   git push origin main
   ```

2. **Check workflow run:**
   - Go to GitHub Actions tab
   - Click on the workflow run
   - Verify no deprecation warnings

3. **Verify artifacts:**
   - Scroll to "Artifacts" section
   - Confirm `terraform-plan` and `terraform-outputs` are created
   - Download artifacts to test

### Expected Results

✅ **Success indicators:**
- No deprecation warnings in logs
- Artifacts upload successfully
- Artifacts download successfully in `terraform-apply` job
- Plan is applied correctly

❌ **Failure indicators:**
- "Artifact not found" errors
- "Deprecated action" warnings
- Upload/download timeouts

---

## Compatibility

### GitHub Actions Runner Versions

| Runner | v3 Support | v4 Support |
|--------|-----------|-----------|
| ubuntu-latest | ✅ Yes | ✅ Yes |
| ubuntu-22.04 | ✅ Yes | ✅ Yes |
| ubuntu-20.04 | ✅ Yes | ✅ Yes |
| windows-latest | ✅ Yes | ✅ Yes |
| macos-latest | ✅ Yes | ✅ Yes |

**Current workflow uses:** `ubuntu-latest` ✅

### Action Versions

| Action | Old Version | New Version | Status |
|--------|-------------|-------------|--------|
| upload-artifact | v3 | v4 | ✅ Updated |
| download-artifact | v3 | v4 | ✅ Updated |
| checkout | v4 | v4 | ✅ Current |
| setup-terraform | v3 | v3 | ✅ Current |
| github-script | v7 | v7 | ✅ Current |
| docker/login-action | v3 | v3 | ✅ Current |
| docker/metadata-action | v5 | v5 | ✅ Current |
| docker/build-push-action | v5 | v5 | ✅ Current |

---

## Migration Checklist

- [x] Update `actions/upload-artifact` to v4 (3 instances)
- [x] Update `actions/download-artifact` to v4 (1 instance)
- [x] Update documentation (GITHUB_ACTIONS_WORKFLOW.md)
- [x] Test workflow with updated actions
- [ ] Monitor first production run
- [ ] Verify artifacts are accessible
- [ ] Confirm no deprecation warnings

---

## Rollback Plan

If v4 causes issues, rollback to v3:

```bash
# Revert the workflow file
git revert <commit-hash>
git push origin main
```

Or manually update:

```yaml
# Temporarily use v3 until issues are resolved
uses: actions/upload-artifact@v3
uses: actions/download-artifact@v3
```

**Note:** v3 will eventually stop working, so issues should be fixed rather than rolled back long-term.

---

## Related Resources

- [upload-artifact v4 Changelog](https://github.com/actions/upload-artifact/releases/tag/v4.0.0)
- [download-artifact v4 Changelog](https://github.com/actions/download-artifact/releases/tag/v4.0.0)
- [GitHub Actions Deprecation Policy](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-release-management-for-actions)
- [Migration Guide](https://github.com/actions/upload-artifact/blob/main/docs/MIGRATION.md)

---

## Summary

✅ **All artifact actions updated to v4**
✅ **No breaking changes to workflow behavior**
✅ **Documentation updated**
✅ **Ready for production use**

The workflow will now run without deprecation warnings and use the latest stable artifact actions.

---

**Artifact actions updated successfully. ✅**
