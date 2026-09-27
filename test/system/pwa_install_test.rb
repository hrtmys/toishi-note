require "application_system_test_case"

class PwaInstallTest < ApplicationSystemTestCase
  # Chrome only offers "Install app" when this list is empty; anything else
  # leaves "install page as app", which pins whatever URL is open.
  test "Chrome reports no installability errors" do
    sign_in_as users(:one)
    visit root_url

    errors = []
    begin
      wait_until("installability errors never cleared") { (errors = installability_errors).empty? }
    rescue Timeout::Error
      flunk "Chrome won't offer to install the app: #{errors.map { |e| e['errorId'] }.join(', ')}"
    end
  end

  private

    def installability_errors
      page.driver.browser.execute_cdp("Page.getInstallabilityErrors")["installabilityErrors"]
    end
end
