ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest" #activează integrarea cu testele Minitest.

WebMock.disable_net_connect!(allow_localhost: true)

#disable_net_connect! blochează cererile reale către internet în teste. Astfel, o cerere către Gemini fără răspuns simulat va produce o eroare locală.
#allow_localhost: true permite conexiunile locale, necesare pentru testele care pornesc aplicația pe calculatorul tău.

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
