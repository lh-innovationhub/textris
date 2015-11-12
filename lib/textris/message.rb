module Textris
  class Message
    attr_reader :content, :from_name, :from_phone, :to, :texter, :action, :args

    def initialize(options = {})
      initialize_content(options)
      initialize_author(options)
      initialize_recipients(options)

      @texter = options[:texter]
      @action = options[:action]
      @args   = options[:args]
    end

    def deliver
      deliveries = ::Textris::Delivery.get
      deliveries.each do |delivery|
        delivery.new(self).deliver_to_all
      end

      self
    end

    def texter(options = {})
      if options[:raw]
        @texter
      elsif @texter.present?
        @texter.to_s.split('::').last.to_s.sub(/Texter$/, '')
      end
    end

    def from
      if @from_phone.present?
        if @from_name.present?
          "#{@from_name} <#{Phony.format(@from_phone)}>"
        else
          Phony.format(@from_phone)
        end
      elsif @from_name.present?
        @from_name
      end
    end

    def content
      @content ||= parse_content(@renderer.render_content)
    end

    private

    def initialize_content(options)
      if options[:content].present?
        @content  = parse_content options[:content]
      elsif options[:renderer].present?
        @renderer = options[:renderer]
      else
        raise(ArgumentError, "Content must be provided")
      end
    end

    def initialize_author(options)
      if options.has_key?(:from)
        @from_name, @from_phone = parse_from options[:from]
      else
        @from_name  = options[:from_name]
        @from_phone = options[:from_phone]
      end
    end

    def initialize_recipients(options)
      @to = parse_to options[:to]

      unless @to.present?
        raise(ArgumentError, "Recipients must be provided and E.164 compilant")
      end
    end

    def parse_from(from)
      parse_from_dual(from) || parse_from_singular(from)
    end

    def parse_from_dual(from)
      if (matches = from.to_s.match(/(.*)\<(.*)\>\s*$/).to_a).size == 3 &&
          Phony.plausible?(matches[2])
        [matches[1].strip, Phony.normalize(matches[2])]
      end
    end

    def parse_from_singular(from)
      if Phony.plausible?(from)
        [nil, Phony.normalize(from)]
      elsif from.present?
        [from.strip, nil]
      end
    end

    def parse_to(to)
      to = [*to]
      to = to.select { |phone| Phony.plausible?(phone.to_s) }
      to = to.map    { |phone| Phony.normalize(phone.to_s) }

      to
    end

    def parse_content(content)
      content = content.to_s
      content = content.squeeze(' ')
      content = content.strip

      content
    end
  end
end
