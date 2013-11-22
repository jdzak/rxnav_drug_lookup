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
    concepts_in_definition(json)
  end

  def find_role_concepts_by_nui_and_role(nui, role)
    response = @connection.get "http://rxnav.nlm.nih.gov/REST/Ndfrt/allInfo/#{nui}"
    json = JSON.parse(response.body)
    role_concepts_in_definition(json)
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

  #MECHANISM_OF_ACTION_KIND
  def concepts_in_definition(json)
    concepts = []
    if group_concept = json['groupConcepts'].compact
      if concept_defs = group_concept && group_concept.map{|gc| gc['concept'] }
        if concept_defs
          concept_defs.flatten!
          concepts = concept_defs.map do |d|
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

  def role_concepts_in_definition(json)
    concepts = []
    if full_concept = json['fullConcept']
      if group_roles = full_concept['groupRoles']
        group_roles.compact!
        if roles = group_roles && group_roles.map{ |gr| gr['role'] }
          if roles
            roles.flatten!
            refined_roles = roles.select{ |r| r['roleName'] =~ /has_MoA/i }
            if concept_defs = refined_roles.map{ |r| r['concept'] }
              concept_defs.flatten!
              concepts = concept_defs.map do |c| 
                nui = c['conceptNui']
                name = c['conceptName']
                kind = c['conceptKind']
                Concept.new(nui, name, kind)
              end
            end
          end
        end
      end
    end
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

    role_concepts = resource.find_role_concepts_by_nui_and_role(nui, 'MECHANISM_OF_ACTION_KIND')

    moa_tree = role_concepts.inject([]) do |memo, c|
      memo << c
      memo += resource.find_parent_concepts_by_nui(c[:nui])
      memo
    end

    puts "#{child[:name]} (#{cui}) has MoA ancestors: #{moa_tree.map{ |c| c[:name] }.sort}"
  else
    puts "CUI not found: #{cui}"
  end
end