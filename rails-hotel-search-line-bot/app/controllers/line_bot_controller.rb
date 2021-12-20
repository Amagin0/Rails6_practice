class LineBotController < ApplicationController
  protect_from_forgery except: [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = search_and_create_message(event.message['text'])
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private

    def client
      @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV['LINE_CHANNEL_SECRET']
        config.channel_token = ENV['LINE_CHANNEL_TOKEN']
      }
    end

    def search_and_create_message(keyword)
     http_client = HTTPClient.new
      url = 'https://app.rakuten.co.jp/services/api/Travel/KeywordHotelSearch/20170426'
      query = {
        'keyword' => keyword,
        'applicationId' => ENV['RAKUTEN_APPID'],
        'hits' => 5,
        'responseType' => 'small',
        'datumType' => 1,
        'formatVersion' => 2
      }
      response = http_client.get(url, query)
      response = JSON.parse(response.body)

      if response.key?('error')
        text ="この検索条件に該当する宿泊施設が見つかりませんでした。\n条件を変えて再検索してください。"
        {
          type: 'text',
          text: text
        }
      else
        {
          type: 'flex',
          altText: '宿泊検索の結果です。',
          contents: set_carousel(response['hotels'])
        }
      end
    end

    def set_carousel(hotels) #カルーセルコンテナ
      bubbles = [] #Arrayクラスの変数bubblesを宣言
      hotels.each do |hotel|
        bubbles.push set_bubble(hotel[0]['hotelBasicInfo'])
        #pushは配列の末尾に要素を追加する。
        #set_bubbleにはホテル名やホテル画像などの
        #基本情報が格納されているhotel[0]['hotelBasicInfo']を渡す
      end
      {
        type: 'carousel',
        contents: bubbles #バブルコンテナの配列。最大10個
      }
    end
    # 楽天トラベルキーワード検索APIから受け取ったホテル情報を一つずつset_bubbleメソッドに渡し、バブルコンテナを作成します。
    # 作成したバブルコンテナは、配列bubblesに順次追加されます。
    # すべてのバブルコンテナを配列にまとめた、カルーセルコンテナを作成します。

    def set_bubble(hotel)
      {
        type: 'bubble',
        hero: set_hero(hotel),
        body: set_body(hotel),
        footer: set_footer(hotel)
      }
    end

    def set_hero(hotel) #ヒーローブロック
      {
        type: 'image',
        url: hotel['hotelImageUrl'], #画像のURL
        size: 'full',
        aspectRatio: '20:13',
        aspectMode: 'cover',
        action: {
          type: 'uri',
          uri: hotel['hotelInformationUrl'] #楽天トラベルのホテルの個別URL
        }
      }
    end
    def set_body(hotel) #ボディブロック
      {
        type: 'box',
        layout: 'vertical',
        contents: [
          {
            type: 'text',
            text: hotel['hotelName'], #ホテル名
            wrap: true,
            weight: 'bold',
            size: 'md'
          },
          {
            type: 'box',
            layout: 'vertical',
            margin: 'lg',
            spacing: 'sm',
            contents: [
              {
                type: 'box',
                layout: 'baseline',
                spacing: 'sm',
                contents: [
                  {
                    type: 'text',
                    text: '住所',
                    color: '#aaaaaa',
                    size: 'sm',
                    flex: 1
                  },
                  {
                    type: 'text',
                    text: hotel['address1'] + hotel['address2'], #都道府県が"1",都道府県以下が"2"
                    wrap: true,
                    color: '#666666',
                    size: 'sm',
                    flex: 5
                  }
                ]
              },
              {
                type: 'box',
                layout: 'baseline',
                spacing: 'sm',
                contents: [
                  {
                    type: 'text',
                    text: '料金',
                    color: '#aaaaaa',
                    size: 'sm',
                    flex: 1
                  },
                  {
                    type: 'text',
                    text: '￥' + hotel['hotelMinCharge'].to_s(:delimited) + '〜',
                    #￥〇〇～みたいに表示させる。to_sでsrtingクラスにしたことによって
                    #5,000のように表示できる。
                    wrap: true,
                    color: '#666666',
                    size: 'sm',
                    flex: 5
                  }
                ]
              }
            ]
          }
        ]
      }
    end

    def set_footer(hotel) #フッターブロック
      {
        type: 'box',
        layout: 'vertical',
        spacing: 'sm',
        contents: [
          {
            type: 'button',
            style: 'link',
            height: 'sm',
            action: {
              type: 'uri',
              label: '電話する',
              uri: 'tel:' + hotel['telephoneNo'] #tel:ホテルの電話番号と表示される
            }
          },
          {
            type: 'button',
            style: 'link',
            height: 'sm',
            action: {
              type: 'uri',
              label: '地図を見る',
              uri: 'https://www.google.com/maps?q=' + hotel['latitude'].to_s + ',' + hotel['longitude'].to_s
              #googleマップからURLを取得し、緯度と経緯で場所を指定。
              #緯度と経度を区切るため" + ',' + "が途中に入っている。
              #hotel['latitube']とhotel['longitube']はintegerなのでstringに変換
            }
          },
          {
            type: 'spacer',
            size: 'sm'
          }
        ],
        flex: 0
      }
    end
end
