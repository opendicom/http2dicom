//
//  Sample object used for demonstrating the RESTful API built using swift-nio-http2.
//
//  person.swift
//  http2dicom
//
//  Created by Kyle Johnson on 8/8/18.
//

import Foundation

struct Person: Codable {
    let id: Int
    let name: String
    let age: Int
}

extension Person: Equatable {
    static func ==(lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.age == rhs.age
    }
}

struct PersonResource {
    
    // MARK: GET
    func get(request: Request) -> Response {
        let (_, matchingObjects): ([Person], [Person]) = getObjectsForRequest(request: request, key: "persons")
        return jsonResponseForValue(matchingObjects)
    }
    
    // MARK: PUT
    func create(request: Request) -> Response {
        // convert json data to object
        guard let object = createPerson(from: request.body) else {
            return responseForCode(.badRequest, "failed to interpret json as person")
        }
        var objects: [Person] = getAllObjects(forKey: "persons")
        objects.append(object)
        setValue(objects, forKey: "persons")
        return responseForCode(.ok, "person created")
    }
    
    // MARK: PATCH
    func update(request: Request) -> Response {
        let (allObjects, matchingObjects): ([Person], [Person]) = getObjectsForRequest(request: request, key: "persons")
        
        // ensure we have a single match
        let index = getIndexOfPerson(allObjects, matchingObjects)
        guard index >= 0 else {
            return index == IndexError.noMatches.rawValue ? responseForCode(.notFound, "match not found") : responseForCode(.badRequest, "match inconclusive")
        }
        
        // update person with properties from request (ignoring id changes)
        let person = allObjects[index]
        let properties = convertJsonToDict(json: request.body)
        let newName = properties["name"] as? String ?? person.name
        let newAge = properties["age"] as? Int ?? person.age
        let updatedObject = Person(id: person.id, name: newName, age: newAge)
        
        // update object in storage
        var updatedObjects = allObjects
        updatedObjects[index] = updatedObject
        setValue(updatedObjects, forKey: "persons")
        return responseForCode(.ok, "person updated")
    }
    
    // MARK: DELETE
    func delete(request: Request) -> Response {
        let (allObjects, matchingObjects): ([Person], [Person]) = getObjectsForRequest(request: request, key: "persons")
        
        // ensure we're matching one or all
        let index = getIndexOfPerson(allObjects, matchingObjects)
        if index == IndexError.noMatches.rawValue {
            return responseForCode(.notFound, "match not found")
        } else if allObjects.count > 1, matchingObjects == allObjects {
            resetIdCount(forKey: "persons")
            setValue([Person](), forKey: "persons")
            return responseForCode(.ok, "db reset")
        }
        
        // remove object from storage
        var remainingObjects = allObjects
        remainingObjects.remove(at: index)
        setValue(remainingObjects, forKey: "persons")
        return responseForCode(.ok, "person deleted")
    }
}

// MARK: - Helpers
extension PersonResource {
    
    private func createPerson(from json: String) -> Person? {
        let properties = convertJsonToDict(json: json)
        let id = getLatestId(forKey: "persons")
        guard let name = properties["name"] as? String,
            let age = properties["age"] as? Int else {
                return nil
        }
        return Person(id: id, name: name, age: age)
    }
    
    private enum IndexError: Int {
        case noMatches = -1
        case multipleMatches = -2
    }
    
    private func getIndexOfPerson(_ allObjects: [Person], _ matchingObjects: [Person]) -> Int {
        guard matchingObjects.count == 1,
            let person = matchingObjects.first,
            let index = allObjects.firstIndex(of: person) else {
                return matchingObjects.count == 0 ? IndexError.noMatches.rawValue : IndexError.multipleMatches.rawValue
        }
        return index
    }
}
