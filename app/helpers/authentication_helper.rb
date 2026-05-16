module AuthenticationHelper
  # The centered single-column shell shared by every sign-in / password
  # page: flash banners, the page title, then the yielded form.
  def auth_panel(title, &block)
    tag.div class: "max-w-sm mx-auto px-6 py-16 sm:py-24" do
      safe_join([
        flash_banners,
        tag.h1(title, class: "ui-title mb-12"),
        capture(&block)
      ])
    end
  end
end
