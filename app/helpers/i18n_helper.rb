module I18nHelper
  def translate(key, options={})
    super(key, options.merge(raise: true))
  rescue I18n::MissingTranslationData
    begin
      super(key, options.merge(raise: true, locale: :en))
    rescue I18n::MissingTranslationData
      key.split(/\./).last.capitalize
    end
  end
  alias :t :translate
end
