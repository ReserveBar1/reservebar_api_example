require 'sinatra'
require 'haml'
require 'pry'
require 'httparty'

# --------------------App_Routes--------------------#
get '/' do
  @brands_resp = HTTParty.get(base_url + 'brands.json', basic_auth: auth)
  @brands = @brands_resp['brands'] || ['error']
  @products = HTTParty.get("#{base_url}products.json?brand=Jameson",
                           basic_auth: auth)
  haml :index
end

get '/brand_products/:brand' do
  @products = HTTParty.get("#{base_url}products.json?brand=#{params[:brand]}",
                           basic_auth: auth)
  haml :products
end

get '/products/:product' do
  response = HTTParty.get("#{base_url}products/#{params[:product]}",
                          basic_auth: auth)
  @product = response
  haml :product
end

post '/order' do
  body = { order:
           { line_items:
             {
               '0' => { variant_id: params[:sku],
                        quantity: params[:quantity] }
             }
           }
         }
  response = HTTParty.post("#{base_url}orders",
                           body: body,
                           basic_auth: auth)
  @order_status = JSON.parse(response.body)
  haml :order
end

post '/checkout' do
  body = { id: params[:number], order_token: params[:token],
           order: { email: 'guest@rbar.com' }
         }
  response = HTTParty.put("#{base_url}checkouts/#{params[:number]}",
                           body: body,
                           basic_auth: auth)
  @order_status = JSON.parse(response.body)
  haml :checkout
end


post '/address' do
  billing_address = shipping_address = {
    firstname: params[:firstname],
    lastname: params[:lastname],
    address1: params[:address1],
    city: params[:city],
    zipcode: params[:zipcode],
    phone: params[:phone],
    state: params[:state],
    country_id: 214
  }
  params[:is_legal_age] = params[:is_legal_age] == 'on' ? true : false
  body = { id: params[:number], order_token: params[:token],
           order: {
                    email: 'guest@rbar.com',
                    ship_address_attributes: shipping_address,
                    bill_address_attributes: billing_address,
                    is_legal_age: params[:is_legal_age]
                  }
         }

  @resp = HTTParty.put("#{base_url}checkouts/#{params[:number]}",
                           body: body,
                           basic_auth: auth)

  @order_status = JSON.parse(@resp.body)
  @shipping_methods = get_shipping_methods
  haml :delivery
end

post '/delivery' do
  body = { id: params[:number], order_token: params[:token],
           order: { shipping_method_id: params[:shipping_method] }
         }
  @resp = HTTParty.put("#{base_url}checkouts/#{params[:number]}",
                           body: body,
                           basic_auth: auth)

  @order_status = JSON.parse(@resp.body)
  haml :payment
end

post '/payment' do
  body = { id: params[:number], order_token: params[:token],
           order: {
                    bill_address_id: params[:bill_address_id],
                    has_accepted_terms: params[:checkbox],
                    payment_source:
                    {
                      "1" =>
                       {
                         "first_name" => params[:first_name],
                         "last_name" => params[:last_name],
                         "number" => params[:number],
                         "month" => params[:month],
                         "year" => params[:year],
                         "verification_value" => params[:card_code]
                       }
                    }
                  }
         }
  @resp = HTTParty.put("#{base_url}checkouts/#{params[:order_number]}",
                           body: body,
                           basic_auth: auth)
  @order_status = JSON.parse(@resp.body)
  haml :complete
end

def get_shipping_methods
  @resp = HTTParty.get("#{base_url}shipping_methods",
                           basic_auth: auth)
  JSON.parse(@resp.body)
end

def base_url
  #'http://localhost:3000/api/'
   'http://staging.reservebar.com/api/'
end

def auth
  { username: 'admin@reservebar.com', password: 'Reservebar12' }
end
