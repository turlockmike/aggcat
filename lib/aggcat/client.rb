module Aggcat
  class Client < Aggcat::Base

    BASE_URL = 'https://financialdatafeed.platform.intuit.com/rest-war/v1'

    def initialize(options={})
      raise ArgumentError.new('customer_id is required for scoping all requests') if options[:customer_id].nil? || options[:customer_id].to_s.empty?
      Aggcat::Configurable::KEYS.each do |key|
        instance_variable_set(:"@#{key}", options[key] || Aggcat.instance_variable_get(:"@#{key}"))
      end
    end

    def institutions
      get('/institutions')
    end

    def institution(institution_id)
      validate(institution_id: institution_id)
      get("/institutions/#{institution_id}")
    end

    def discover_and_add_accounts(institution_id, username, password)
      validate(institution_id: institution_id, username: username, password: password)
      body = credentials(institution_id, username, password)
      post("/institutions/#{institution_id}/logins", body)
    end

    def account_confirmation(institution_id, challenge_session_id, challenge_node_id, answer)
      validate(institution_id: institution_id, challenge_node_id: challenge_session_id, challenge_node_id: challenge_node_id, answer: answer)
      headers = {challengeSessionId: challenge_session_id, challengeNodeId: challenge_node_id}
      post("/institutions/#{institution_id}/logins", challenge_answer(answer), headers)
    end

    def accounts
      get('/accounts')
    end

    def account(account_id)
      validate(account_id: account_id)
      get("/accounts/#{account_id}")
    end

    def account_transactions(account_id, start_date, end_date = nil)
      validate(account_id: account_id, start_date: start_date)
      uri = "/accounts/#{account_id}/transactions?txnStartDate=#{start_date.strftime(DATE_FORMAT)}"
      if end_date
        uri += "&txnEndDate=#{end_date.strftime(DATE_FORMAT)}"
      end
      get(uri)
    end

    def update_login(institution_id, login_id, username, password)
      validate(institution_id: institution_id, login_id: login_id, username: username, password: password)
      body = credentials(institution_id, username, password)
      put("/logins/#{login_id}?refresh=true", body)
    end

    def update_login_confirmation(login_id, challenge_session_id, challenge_node_id, answer)
      validate(login_id: login_id, challenge_node_id: challenge_session_id, challenge_node_id: challenge_node_id, answer: answer)
      headers = {challengeSessionId: challenge_session_id, challengeNodeId: challenge_node_id}
      put("/logins/#{login_id}?refresh=true", challenge_answer(answer), headers)
    end

    def delete_account(account_id)
      validate(account_id: account_id)
      delete("/accounts/#{account_id}")
    end

    def delete_customer
      delete('/customers')
    end

    protected

    def get(uri, headers = {})
      request(:get, uri, headers)
    end

    def post(uri, body, headers = {})
      request(:post, uri, body, headers.merge({'Content-Type' => 'application/xml'}))
    end

    def put(uri, body, headers = {})
      request(:put, uri, body, headers.merge({'Content-Type' => 'application/xml'}))
    end

    def delete(uri, headers = {})
      request(:delete, uri, headers.merge({'Content-Type' => 'application/xml'}))
    end

    private

    def request(method, uri, *options)
      response = access_token.send(method.to_sym, BASE_URL + uri, *options)
      result = {:response_code => response.code, :response => parse_xml(response.body)}
      if response['challengeSessionId']
        result[:challenge_session_id] = response['challengeSessionId']
        result[:challenge_node_id] = response['challengeNodeId']
      end
      result
    end

    def validate(args)
      args.each do |name, value|
        if value.nil? || value.to_s.empty?
          raise ArgumentError.new("#{name} is required")
        end
      end
    end

    def credentials(institution_id, username, password)
      institution = institution(institution_id)
      keys = institution[:response][:institution_detail][:keys][:key].sort { |a, b| a[:display_order] <=> b[:display_order] }
      hash = {
          keys[0][:name] => username,
          keys[1][:name] => password
      }

      xml = Builder::XmlMarkup.new
      xml.InstitutionLogin('xmlns' => LOGIN_NAMESPACE) do |login|
        login.credentials('xmlns:ns1' => LOGIN_NAMESPACE) do
          hash.each do |key, value|
            xml.tag!('ns1:credential', {'xmlns:ns2' => LOGIN_NAMESPACE}) do
              xml.tag!('ns2:name', key)
              xml.tag!('ns2:value', value)
            end
          end
        end
      end
    end

    def challenge_answer(answer)
      xml = Builder::XmlMarkup.new
      xml.InstitutionLogin('xmlns:v1' => LOGIN_NAMESPACE) do |login|
        login.challengeResponses do |challenge|
          challenge.response(answer, 'xmlns:v11' => CHALLENGE_NAMESPACE)
        end
      end
    end
  end
end


