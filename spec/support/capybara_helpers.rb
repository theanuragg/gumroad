# frozen_string_literal: true

module CapybaraHelpers
  def wait_for_valid(javascript_expression)
    page.document.synchronize do
      raise Capybara::ElementNotFound unless page.evaluate_script(javascript_expression)
    end
  end

  def wait_for_visible(selector)
    wait_for_valid %($('#{selector}:visible').length > 0)
  end

  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    page.evaluate_script(<<~EOS)
      ((typeof window.jQuery === 'undefined') || jQuery.active === 0) && !window.__activeRequests
    EOS
  end

  def visit(url)
    page.visit(url)
    return if Capybara.current_driver == :rack_test
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script("document.readyState") == "complete"
    end
    wait_for_ajax
  end

  def wait_until_true
    Timeout.timeout(Capybara.default_max_wait_time) do
      until yield
        sleep 1
      end
    end
  end

  def js_style_encode_uri_component(comp)
    # CGI.escape encodes spaces to "+"
    # but encodeURIComponent in JS encodes them to "%20"
    CGI.escape(comp).gsub("+", "%20")
  end

  def fill_in_color(field, color)
    field.execute_script("Object.getOwnPropertyDescriptor(Object.getPrototypeOf(this), 'value').set.call(this, arguments[0]); this.dispatchEvent(new Event('input', { bubbles: true }))", color)
  end

  def have_nth_table_row_record(n, text, exact_text: true)
    have_selector("tbody tr:nth-child(#{n}) > td", text:, exact_text:, normalize_ws: true)
  end

  def get_client_time_zone
    page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")
  end
end
