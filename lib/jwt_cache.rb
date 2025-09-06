module JwtCache
  module_function

  def read_access_token(user_id)
    hash = Rails.cache.read("#{user_id}/access_token_hash")
    return unless hash

    IdentityClient.from_hash(hash)
  end

  def write_access_token(user_id, new_access_token)
    Rails.cache.write(
      "#{user_id}/access_token_hash",
      new_access_token.to_hash,
      expires_in: 20.minutes
    )
  end
end