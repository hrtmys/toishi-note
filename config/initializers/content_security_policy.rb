# Be sure to restart your server when you modify this file.
#
# A real CSP only became viable once CDN <script>/<link> tags and
# per-view inline <style> blocks were eliminated (see asset-strategy.md).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # No 'unsafe-inline' here — this is the directive that actually
    # matters against XSS, and every <script> in the app is either an
    # external, same-origin file (javascript_include_tag) or absent.
    policy.script_src :self
    # 'unsafe-inline' is required, not a shortcut: Bootstrap style="..."
    # attributes and KaTeX/Mermaid's inline styles both need it. Removing
    # this silently breaks math/diagram rendering rather than raising.
    policy.style_src :self, :unsafe_inline
    # data: is real, not defensive-by-default: Mermaid's C4 diagram type
    # embeds a small icon as a base64 data URI at render time.
    policy.img_src :self, :data
    policy.font_src :self
    policy.object_src :none
    policy.base_uri :self
    # This app is never meant to be framed by another site.
    policy.frame_ancestors :self
  end

  # This sends a real CSP header on every response, enforcing
  # frame-ancestors (the spec disallows that via <meta>).
end
