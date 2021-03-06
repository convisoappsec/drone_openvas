#
# Copyright 2013 by Antonio Costa (acosta@conviso.com.br)
#
# This file is part of the Drone openvas project.
# Drone Template is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
require "rubygems"
require 'xmpp4r/client'
require 'base64'
require 'builder'

# Jabber::debug = true

module Communication
  class XMPP
# inicia conexao com jabber e fica recebendo xml, e escrevendo 
# na pasta "trunk/input" os xml...
    def initialize(config = nil, debug = nil) # user,pass)
      @config = config
      @debug = debug
      @msg_queue = []
      @active=false
      @cl = Jabber::Client.new(Jabber::JID.new(@config['xmpp']['username']))
      @active = false

      @cl.add_message_callback do |m|
        if m.type != :error && m.body.to_s.size > 1
          @msg_queue << m.body
        end
      end
      
      __connenct()
    end

    # TODO: Fazer com que esse metodo apenas receba uma string com um payload
    def send_msg(issue = '', config = nil)
      @debug.info('Sending message ...')
      
      return false if !self.active?
      
      begin
        msg = Jabber::Message.new(@config['xmpp']['importer_address'], issue)
        msg.type = :normal
        @cl.send(msg)
      rescue
        @debug.error('Send message error')
        return false
      end

      sleep @config['xmpp']['send_delay'].to_f
      return true
    end

    def product_xml(issue, config)
      xml = Builder::XmlMarkup.new( :ident => 2)
      xml.instruct! :xml, :encoding => 'ASCII'

      xml.scan do |s|
        s.header do |h|
          h.tool 'openvas'
          h.scope config['client']
          h.project config['project_id']
          h.timestamp Time.now
        end

        s.vulnerabilities do |vs|
          vs.vulnerability do |v|
          v.hash issue[:hash]
            v.title Base64.encode64(issue[:name].to_s)
            v.description Base64.encode64("#{issue[:host]} \n\n #{issue[:description]}")
            v.optional do |vo|
              vo.reference Base64.encode64(issue[:original_threat].to_s)
              vo.reproduction Base64.encode64("#{issue[:cve]} ")
              vo.exploitability issue[:risk_factor].to_s.downcase
            end
          end
        end
      end
    end

    def receive_msg
      (1..@msg_queue.size).to_a.collect{@msg_queue.pop}.join('_')
    end

    def active?
      @active
    end

    def __connenct
      begin
        @cl.connect
        @cl.auth(@config['xmpp']['password'])
        @cl.send(Jabber::Presence.new.set_type(:available))
        @active = 
        @debug.info('Drone connected.')
      rescue
        @debug.error('Cannot connect to XMPP server. Please check network connection and XMPP credentials.')
      end 
    end
  end

end
