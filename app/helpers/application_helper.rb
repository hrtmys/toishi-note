module ApplicationHelper
  # Whether the session was established by a trusted reverse proxy header
  # rather than a password login. Deployment-wide, not per-user: if
  # enabled, every account authenticates this way.
  def trusted_header_auth?
    TrustedHeaderLogin.enabled?
  end

  # Whether this is a "Just me" (solo) or "My team" deployment. Solo means
  # one pinned account (trusted_header_owner) under header auth, or no
  # admin account at all under password auth.
  def solo_deployment?
    if trusted_header_auth?
      Current.user.trusted_header_owner?
    else
      !User.admin.exists?
    end
  end

  # Reuses Setup's own "Just me" / "My team" labels (setup.mode_solo /
  # setup.mode_team) rather than a second, separately-translated pair —
  # this is the same choice made there, just described after the fact.
  def deployment_mode_label
    t(solo_deployment? ? "setup.mode_solo" : "setup.mode_team")
  end
end
