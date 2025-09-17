# frozen_string_literal: true

module BrazilianHelper
  # Formata valores em Real brasileiro
  def format_currency(amount)
    number_to_currency(amount, locale: :"pt-BR")
  end

  # Formata CPF
  def format_cpf(cpf)
    return cpf unless cpf.present? && cpf.length == 11
    cpf.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4')
  end

  # Formata CNPJ
  def format_cnpj(cnpj)
    return cnpj unless cnpj.present? && cnpj.length == 14
    cnpj.gsub(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '\1.\2.\3/\4-\5')
  end

  # Formata telefone brasileiro
  def format_phone(phone)
    return phone unless phone.present?

    # Remove todos os caracteres não numéricos
    numbers = phone.gsub(/\D/, "")

    case numbers.length
    when 10
      numbers.gsub(/(\d{2})(\d{4})(\d{4})/, '(\1) \2-\3')
    when 11
      numbers.gsub(/(\d{2})(\d{5})(\d{4})/, '(\1) \2-\3')
    else
      phone
    end
  end

  # Formata data/hora no padrão brasileiro
  def format_brazilian_datetime(datetime)
    return "" unless datetime.present?
    l(datetime, format: :default)
  end

  # Formata apenas a data no padrão brasileiro
  def format_brazilian_date(date)
    return "" unless date.present?
    l(date, format: :default)
  end

  # Status com tradução PIX
  def pix_status_badge(status)
    css_class = case status.to_s
    when "active", "completed", "approved"
                  "bg-green-100 text-green-800"
    when "pending", "processing"
                  "bg-yellow-100 text-yellow-800"
    when "failed", "rejected", "canceled"
                  "bg-red-100 text-red-800"
    else
                  "bg-gray-100 text-gray-800"
    end

    content_tag(:span, t("pix.transaction_status.#{status}", default: status.humanize),
                class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{css_class}")
  end

  # Formatação para chaves PIX
  def format_pix_key(key_type, key_value)
    return key_value unless key_value.present?

    case key_type.to_s.downcase
    when "cpf"
      format_cpf(key_value)
    when "cnpj"
      format_cnpj(key_value)
    when "phone"
      format_phone(key_value)
    when "email"
      key_value
    when "random"
      key_value
    else
      key_value
    end
  end
end
