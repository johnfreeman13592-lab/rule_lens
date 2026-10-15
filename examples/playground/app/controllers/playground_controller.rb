class PlaygroundController < ApplicationController
  class InvalidInput < StandardError; end

  def show
    @values = { "before_amount" => "4000", "after_amount" => "5000",
                "before_destination" => "domestic", "after_destination" => "domestic" }
    @comparison = ShippingRules::BOOK.compare(before: input_for("before"), after: input_for("after"))
  end

  def compare
    @values = params.permit(:before_amount, :after_amount, :before_destination, :after_destination).to_h
    @comparison = ShippingRules::BOOK.compare(before: input_for("before"), after: input_for("after"))
    render :show
  rescue InvalidInput => error
    @error = error.message
    render :show, status: :unprocessable_entity
  end

  private

  def input_for(side)
    value = @values["#{side}_amount"]
    unless value.is_a?(String) && value.match?(/\A[0-9]{1,9}\z/)
      raise InvalidInput, "注文金額は0〜999,999,999の整数で入力してください。"
    end
    destination = @values["#{side}_destination"]
    unless %w[domestic overseas].include?(destination)
      raise InvalidInput, "配送先を国内または海外から選んでください。"
    end
    { amount: Integer(value, 10), destination: destination }.freeze
  end
end
