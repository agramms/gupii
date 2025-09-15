module AppSettings
  module_function

  ROOT = Rails.application.config_for(:application).freeze

  def get(*path)
    # Try Rails credentials first, then config file, then environment variables
    credentials_value = Rails.application.credentials.dig(*path)
    config_file_value = ROOT.dig(*path)
    env_var_value = ENV.fetch(path.join("__").upcase, nil)

    value = credentials_value || config_file_value

    if env_var_value.present?
      case value
      when TrueClass, FalseClass then ActiveModel::Type::Boolean.new.cast(env_var_value)
      when Integer then env_var_value.to_i
      when Numeric then Float(env_var_value)
      else env_var_value
      end
    else
      value
    end
  end

  APP_NAME = AppSettings.get(:appname).freeze
  SERVICE_NAME = ENV.fetch("DD_SERVICE", AppSettings::APP_NAME).freeze
  APP_VERSION = ENV.fetch("DD_VERSION", "").freeze

  API_DOCUMENTATION = AppSettings.get(:api_documentation, :base_url).freeze
  BILLING_BASE_URL = AppSettings.get(:billing, :base_url).freeze
  CORE_BASE_URL = AppSettings.get(:core, :base_url).freeze
  CORE_API_TOKEN = AppSettings.get(:core, :api_token).freeze
  ICP_SIGNATURE_BASE_URL = AppSettings.get(:icp_signature, :base_url).freeze
  ICP_SIGNATURE_SIGN_URL = AppSettings.get(:icp_signature, :sign_url).freeze
  IDENTITY_BASE_URL = AppSettings.get(:identity, :base_url).freeze

  IuguInfo = Struct.new(:company_name, :bank_code, :cnpj)
  IUGU = IuguInfo.new(
    AppSettings.get(:iugu, :company_name),
    AppSettings.get(:iugu, :bank_code),
    AppSettings.get(:iugu, :cnpj)
  ).freeze

  CHECK_INTERVAL = AppSettings.get(:jobs, :check_interval).seconds

  module Oauth
    CLIENT_ID = AppSettings.get(:oauth, :client_id).freeze
    CLIENT_SECRET = AppSettings.get(:oauth, :client_secret).freeze
  end

  module Datadog
    ENABLED = AppSettings.get(:datadog, :enabled).freeze
  end
end
