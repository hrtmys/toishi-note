# Signs a user in from a header set by a trusted reverse proxy,
# auto-provisioning the account on first contact. Disabled unless
# TRUSTED_HEADER_AUTH_HEADER is set — the proxy must strip and re-set it.
class TrustedHeaderLogin
  HEADER_ENV_VAR = "TRUSTED_HEADER_AUTH_HEADER"

  class << self
    def enabled?
      header_name.present?
    end

    def header_name
      ENV[HEADER_ENV_VAR]
    end
  end

  def initialize(request)
    @request = request
  end

  def call
    return unless self.class.enabled?

    email_address = request.headers[self.class.header_name].presence
    return unless email_address

    # A solo deployment pins every request to the account created at
    # setup time, regardless of the header's email — otherwise a second
    # email would silently create a second account.
    User.find_by(trusted_header_owner: true) || User.find_or_create_by!(email_address: email_address) do |user|
      user.password = SecureRandom.base58(32)
    end
  end

  private
    attr_reader :request
end
