require 'faraday'
require 'json'

class Concept < Struct.new(:nui, :name, :kind)
end

class DrugDefinitionResource
  def initialize
    @connection = Faraday.new(:url => 'http://rxnav.nlm.nih.gov') do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      # faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      faraday.headers['Accept'] = 'application/json'
    end
  end

  def find_first_concept_by_cui(cui)
    response = @connection.get "/REST/Ndfrt/idType=UMLSCUI&idString=#{cui}"
    json = JSON.parse(response.body)
    first_concept_in_definition(json)
  end

  def find_parent_concepts_by_nui(nui)
    response = @connection.get "/REST/Ndfrt/parentConcepts/nui=#{nui}&transitive=true"
    json = JSON.parse(response.body)
    concept_in_definition(json)
  end

  private
  def first_concept_in_definition(json)
    concept = nil
    if group_concept = json['groupConcepts'].compact
      if concepts = group_concept && group_concept.map{|gc| gc['concept'] }
        if concepts
          concepts.flatten!
          definitions = concepts.select{|c| c['conceptKind'] =~ /DRUG_KIND/i }
          if definitions.first
            d = definitions.first
            nui = d['conceptNui']
            name = d['conceptName']
            kind = d['conceptKind']
            concept = Concept.new(nui, name, kind)
          end
        end
      end
    end
    concept
  end

  def concept_in_definition(json)
    concepts = []
    if group_concept = json['groupConcepts'].compact
      if concepts = group_concept && group_concept.map{|gc| gc['concept'] }
        if concepts
          concepts.flatten!
          definitions = concepts.select{|c| c['conceptKind'] =~ /DRUG_KIND/i }
          concepts = definitions.map do |d|
            nui = d['conceptNui']
            name = d['conceptName']
            kind = d['conceptKind']
            Concept.new(nui, name, kind)
          end
        end
      end
    end
    concepts
  end
end

resource = DrugDefinitionResource.new

dmard_cuis = %w(C0004482 C0010592 C0020336 C0063041 C0025677 C0036078 C1609165)
gluc_cuis = %w(C0025815 C0032950 C0032952)
nsaid_cuis = %w(C0083381 C0538927 C0762662 C0913246 C0972314 C0012091 C0022635 C0027396 C0972314)
tnf_cuis = %w(C1619966 C1122087 C0245109 C0717758 C0666743 C0393022 C1609165)

cuis = dmard_cuis + gluc_cuis + nsaid_cuis + tnf_cuis

cuis.each do |cui|
  child = resource.find_first_concept_by_cui(cui)

  if child
    nui = child[:nui]

    if nui
      concepts = resource.find_parent_concepts_by_nui(nui)

      puts "#{child[:name]} (#{cui}) has ancesstors: #{concepts.map{ |c| c[:name] }}"
    end
  else
    puts "CUI #{cui} not found"
  end
end