# frozen_string_literal: true

class AdminSearchService
  class InvalidDateError < StandardError; end

  def search_purchases(query: nil, creator_email: nil, license_key: nil, transaction_date: nil, last_4: nil, card_type: nil, price: nil, expiry_date: nil, limit: nil)
    purchases = Purchase.order(created_at: :desc)

    if query.present?
      unions = [
        Gift.select("gifter_purchase_id as purchase_id").where(gifter_email: query).to_sql,
        Gift.select("giftee_purchase_id as purchase_id").where(giftee_email: query).to_sql,
        Purchase.select("id as purchase_id").where(email: query).to_sql,
        Purchase.select("id as purchase_id").where(card_visual: query, card_type: CardType::PAYPAL).to_sql
      ]

      union_sql = <<~SQL.squish
        SELECT purchase_id FROM (
          #{ unions.map { |u| "(#{u})" }.join(" UNION ") }
        ) via_gifts_and_purchases
      SQL
      purchases = purchases.where("id IN (#{union_sql})")
    end

    if creator_email.present?
      user = User.find_by(email: creator_email)
      return Purchase.none unless user
      purchases = purchases.joins(:link).where(links: { user_id: user.id })
    end

    if license_key.present?
      license = License.find_by(serial: license_key)
      return Purchase.none unless license
      purchases = purchases.where(id: license.purchase_id)
    end

    if [transaction_date, last_4, card_type, price, expiry_date].any?
      purchases = purchases.where.not(stripe_fingerprint: nil)

      if transaction_date.present?
        formatted_date = parse_date!(transaction_date)
        start_date = (formatted_date - 1.days).beginning_of_day.to_fs(:db)
        end_date = (formatted_date + 1.days).end_of_day.to_fs(:db)
        purchases = purchases.where("created_at between ? and ?", start_date, end_date)
      end
      purchases = purchases.where(card_type:) if card_type.present?
      purchases = purchases.where(card_visual_sql_finder(last_4)) if last_4.present?
      purchases = purchases.where("price_cents between ? and ?", price.to_i * 75, price.to_i * 125) if price.present?
      if expiry_date.present?
        expiry_month, expiry_year = CreditCardUtility.extract_month_and_year(expiry_date)
        purchases = purchases.where(card_expiry_year: "20#{expiry_year}") if expiry_year.present?
        purchases = purchases.where(card_expiry_month: expiry_month) if expiry_month.present?
      end
    end

    purchases.limit(limit)
  end

  private
    def parse_date!(transaction_date)
      Date.strptime(transaction_date, "%Y-%m-%d").in_time_zone
    rescue ArgumentError
      raise InvalidDateError, "transaction_date must use YYYY-MM-DD format."
    end

    def card_visual_sql_finder(last_4)
      [
        (["card_visual = ?"] * ChargeableVisual::LENGTH_TO_FORMAT.size).join(" OR "),
        *ChargeableVisual::LENGTH_TO_FORMAT.values.map { |visual_format| format(visual_format, last_4) }
      ]
    end
end
