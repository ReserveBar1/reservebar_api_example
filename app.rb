require 'sinatra'
require 'haml'
require 'pry'
require 'httparty'
require 'sinatra/config_file'
require 'timeout'

set :timeout, 900

TIMEOUT = 1000

# --------------------App_Routes--------------------#
get '/' do
  @brands_resp = HTTParty.get(ssl_base_url + 'brands.json', basic_auth: auth)
  @brands = @brands_resp['brands'] || ['error']
  @products = HTTParty.get("#{ssl_base_url}products.json?brand=Jameson",
                           basic_auth: auth)
  haml :index
end

get '/brand_products/:brand' do
  brand = ERB::Util.url_encode(params[:brand])
  @products = HTTParty.get("#{ssl_base_url}products.json?brand=#{brand}",
                           basic_auth: auth)
  haml :products
end

get '/products/:product' do
  response = HTTParty.get("#{ssl_base_url}products/#{params[:product]}",
                          basic_auth: auth)
  @product = response
  haml :product
end

post '/order' do
  body = { order:
           { line_items:
             {
               '0' => { variant_id: params[:variant_id],
                        quantity: params[:quantity] }
             }
           }
         }
  response = HTTParty.post("#{ssl_base_url}orders",
                           body: body,
                           basic_auth: auth)
  @order_status = JSON.parse(response.body)

  return haml :exception if check_for_errors(@order_status)

  haml :order
end

post '/checkout' do
  body = { id: params[:number], order_token: params[:token],
           order: { email: params[:email] }
         }
  response = HTTParty.put("#{ssl_base_url}checkouts/#{params[:number]}",
                          body: body,
                          basic_auth: auth)
  @order_status = JSON.parse(response.body)

  return haml :exception if check_for_errors(@order_status)

  haml :checkout
end

post '/address' do
  shipping_address = {
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
             email: params[:email],
             ship_address_attributes: shipping_address,
             is_legal_age: params[:is_legal_age]
           }
         }
  @resp = HTTParty.put("#{ssl_base_url}checkouts/#{params[:number]}",
                       body: body,
                       basic_auth: auth,
                       timeout: 1000)
  @order_status = JSON.parse(@resp.body)

  return haml :exception if check_for_errors(@order_status)

  @shipping_methods = shipping_methods
  haml :delivery
end

post '/delivery' do
  body = { id: params[:number], order_token: params[:token],
           order: { shipping_method_id: params[:shipping_method] }
         }
  @resp = HTTParty.put("#{ssl_base_url}checkouts/#{params[:number]}",
                       body: body,
                       basic_auth: auth)

  @order_status = JSON.parse(@resp.body)

  return haml :exception if check_for_errors(@order_status)

  haml :payment
end

post '/payment' do
  bill_address = {
    firstname: 'Test',
    lastname: 'Tester',
    address1: '100 First ave',
    city: 'New York',
    zipcode: '10009',
    phone: '1234567890',
    state: 'NY',
    country_id: 214
  }
  params[:terms] = params[:terms] == 'on' ? 1 : 0
  body = { id: params[:number], order_token: params[:token],
           order: {
             bill_address_id: params[:ship_address_id],
             has_accepted_terms: params[:terms],
             payments_attributes: [{
               # payment_method_id: '3', # for development/staging
               payment_method_id: '4', # for production
               source_attributes: {
                 'first_name' => params[:first_name],
                 'last_name' => params[:last_name],
                 'number' => params[:number],
                 'month' => params[:month],
                 'year' => params[:year],
                 'verification_value' => params[:card_code],
                 'address_id' => params[:ship_address_id]
               }
             }]
           },
           bill_address: bill_address
         }
  @resp = HTTParty.put("#{ssl_base_url}checkouts/#{params[:order_number]}",
                       body: body,
                       basic_auth: auth,
                       timeout: 1000)
  @order_status = JSON.parse(@resp.body)

  return haml :exception if check_for_errors(@order_status)

  haml :complete
end

def shipping_methods
  body = { id: params[:number] }
  @resp = HTTParty.put("#{ssl_base_url}shipping_methods",
                       body: body,
                       basic_auth: auth,
                       timeout: 1000)
  JSON.parse(@resp.body)
end

def check_for_errors(api_response)
  if (@exception = api_response['error'])
    return true
  else
    return false
  end
end

def ssl_base_url
  # 'http://localhost:3000/api/'
  # 'https://staging.reservebar.com/api/'
  'https://reservebar.com/api/'
end

def base_url
  # 'http://localhost:3000/api/'
  # 'http://staging.reservebar.com/api/'
  'http://reservebar.com/api/'
end

def auth
  { username: 'admin@reservebar.com', password: 'Reservebar12' }
end
