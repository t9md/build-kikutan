module Filter
  PUNCTUATIONS = ".,、。"
  NANI_NANI = %w(... … 〜 ~)
  NANI_NANI_REGEX_PATTERN = NANI_NANI.map {|e| Regexp.escape(e)}.join('|')
  
  def self.normalize_japanese(text)
    text = text.gsub(/^\[.+\]\s*/, "")

    # 遺棄物{いきぶつ}、遺棄船{いきせん} => いきぶつ、いきせん
    # ひどい,恐{おそ}ろしい => ひどい、おそろしい
    text = text.gsub(/([^#{PUNCTUATIONS}]+?)\{(.+?)\}(#{PUNCTUATIONS.split('').join('|')})?(\s*)/, '\2\3\4')
    text = text.gsub(/(.*?)\{(.*?)\}(,|、)?(\s*)/, '\2\3\4')
    
    text = text.gsub(/#{NANI_NANI_REGEX_PATTERN}/, "なになに")
    text
  end
end
