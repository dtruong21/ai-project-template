        import fake_fcm  # rust/api/tests/fake_fcm.py (added by the push module)
        MODULE_STATE["fcm"] = fake_fcm.FakeGoogle(workdir)
        EXTRA_VARS.extend(MODULE_STATE["fcm"].worker_vars())
