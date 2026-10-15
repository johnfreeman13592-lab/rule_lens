# Application-owned, trusted Ruby definitions. Input comes from the form.
module ShippingRules
  BOOK = RuleLens.define("送料無料") do
    rule :domestic, label: "配送先が国内", reason: "送料無料は国内配送のみ対象です。" do |order|
      order.fetch(:destination) == "domestic"
    end

    rule :minimum, label: "注文金額が5,000円以上", reason: "注文金額を5,000円以上にしてください。" do |order|
      order.fetch(:amount) >= 5000
    end
  end
end
