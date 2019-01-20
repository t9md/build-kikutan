PUNCTUATIONS = ".,、。"

module Filter
  def self.normalize_japanese(text)
    text = text.gsub(/^\[.+\]\s*/, "")

    # 遺棄物{いきぶつ}、遺棄船{いきせん} => いきぶつ、いきせん
    # ひどい,恐{おそ}ろしい => ひどい、おそろしい
    regex_punctuations = /#{PUNCTUATIONS.split('').join('|')}/
    text = text.gsub(/([^#{PUNCTUATIONS}]+?)\{(.+?)\}(#{PUNCTUATIONS})?(\s*)/, '\2\3\4')
    text = text.gsub(/(.*?)\{(.*?)\}(,|、)?(\s*)/, '\2\3\4')
    text = text.gsub("...", "なになに")
    text = text.gsub("〜", "なになに")
    text = text.gsub("~", "なになに")
    text = text.gsub("~", "なになに")
    text
  end
end
