module JwtCache
  module_function

  def read_access_token(user_id)
    hash = Rails.cache.read("#{user_id}/access_token_hash")
    return unless hash

    IdentityClient.from_hash(hash)
  end

  def write_access_token(user_id, new_access_token)
    # Calculate expiration based on token's actual expiry time
    token_expires_in = if new_access_token.expires_at
                         [new_access_token.expires_at - Time.now.to_i, 0].max.seconds
                       else
                         # Default fallback if no expiry in token
                         20.minutes
                       end
    
    # Cache for slightly less time than token expiry to account for network latency
    cache_expires_in = [token_expires_in - 1.minute, 1.minute].max
    
    Rails.cache.write(
      "#{user_id}/access_token_hash",
      new_access_token.to_hash,
      expires_in: cache_expires_in
    )
    
    Rails.logger.debug "[JwtCache] Token cached for user #{user_id}, expires in #{cache_expires_in.inspect}"
  end
end