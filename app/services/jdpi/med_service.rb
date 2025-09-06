module Jdpi
  # Mecanismo Especial de Devolução (MED) service
  # Handles special refund mechanisms for PIX transactions
  class MedService < BaseService
    attr_accessor :transaction_id, :refund_reason, :refund_amount
    
    validates :transaction_id, presence: true
    validates :refund_reason, presence: true
    validates :refund_amount, presence: true, numericality: { greater_than: 0 }
    
    def call
      return false unless valid?
      
      Rails.logger.info "[JDPI MED] Processing refund for transaction #{transaction_id}"
      
      response = client.post("/med/refunds") do |req|
        req.body = {
          transactionId: transaction_id,
          refundReason: refund_reason,
          refundAmount: refund_amount,
          timestamp: Time.current.iso8601
        }
      end
      
      result = handle_response(response)
      
      if result
        Rails.logger.info "[JDPI MED] Refund processed successfully: #{result['refundId']}"
        result
      else
        Rails.logger.error "[JDPI MED] Failed to process refund: #{errors.join(', ')}"
        false
      end
    end
    
    def self.process_refund(transaction_id:, refund_reason:, refund_amount:)
      service = new(
        transaction_id: transaction_id,
        refund_reason: refund_reason,
        refund_amount: refund_amount
      )
      
      service.call
    end
  end
end