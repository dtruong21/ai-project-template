        import fake_revenuecat  # rust/api/tests/fake_revenuecat.py (added by the payments module)
        MODULE_STATE["rc"] = fake_revenuecat.FakeRevenueCat()
        MODULE_STATE["rc_module"] = fake_revenuecat
        EXTRA_VARS.extend(MODULE_STATE["rc"].worker_vars())
