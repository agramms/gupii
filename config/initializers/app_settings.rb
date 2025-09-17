# Legacy AppSettings module - migrated to use AppConfig
# This maintains backward compatibility while using the new AppConfig system

module AppSettings
  module_function

  # Backward compatibility wrapper using AppConfig
  def get(*path)
    key = path.join("_").upcase
    AppConfig.get(key)
  end

  APP_NAME = AppConfig.get("APPNAME", "Gupii").freeze
  SERVICE_NAME = AppConfig.get("DD_SERVICE", APP_NAME).freeze
  APP_VERSION = AppConfig.get("DD_VERSION", "").freeze

  API_DOCUMENTATION = AppConfig.get("API_DOCUMENTATION_BASE_URL").freeze
  BILLING_BASE_URL = AppConfig.get("BILLING_BASE_URL").freeze
  CORE_BASE_URL = AppConfig.get("CORE_BASE_URL").freeze
  CORE_API_TOKEN = AppConfig.get("CORE_API_TOKEN").freeze
  ICP_SIGNATURE_BASE_URL = AppConfig.get("ICP_SIGNATURE_BASE_URL").freeze
  ICP_SIGNATURE_SIGN_URL = AppConfig.get("ICP_SIGNATURE_SIGN_URL").freeze
  IDENTITY_BASE_URL = AppConfig.get("IDENTITY_BASE_URL").freeze

  IuguInfo = Struct.new(:company_name, :bank_code, :cnpj)
  IUGU = IuguInfo.new(
    AppConfig.get("IUGU_COMPANY_NAME"),
    AppConfig.get("IUGU_BANK_CODE"),
    AppConfig.get("IUGU_CNPJ")
  ).freeze

  CHECK_INTERVAL = AppConfig.get_integer("JOBS_CHECK_INTERVAL", 30).seconds

  module Oauth
    CLIENT_ID = AppConfig.get("OAUTH_CLIENT_ID").freeze
    CLIENT_SECRET = AppConfig.get("OAUTH_CLIENT_SECRET").freeze
  end

  module Datadog
    ENABLED = AppConfig.get_boolean("DATADOG_ENABLED", false).freeze
  end
end
