public enum ArgumentError : Error {
	case IllegalArgument(String)
	case IllegalArgumentDefination(String)
	case UsageError(String)
}

/**
 * Command line argument, which composed of
 *     short name, e.g -a
 *     long name, e.g --action
 *     a flag that indicates if the argument has or has not value,
 *     a list of enumeration values, e.g [create|update|delete]
 *     value, the value of argument
 *     a flag that indicates if the argument is mandatory
 *
 * Initialization pattern as the following:
 *
 *    short name,long name,is bare [,value enumeration] [,is mandatory]
 *
 * for example
 *
 *    -a,--action,true,create|update|delete
 *    -t,--type,true,CLOB|BLOB,true
 *    -v,--verbose,false
 *
 *
 *
 * @author Wayne Zhang
 */
class CmdLineArgument : CustomStringConvertible {
	let shortName: String
	let longName: String
	let hasValue: Bool
	let enumValues: Set<String>
	var value: String?
	let isMandatory: Bool

	init(shortName: String, longName: String, hasValue: Bool,
	    enumValues: Set<String>, isMandatory: Bool){
		self.shortName      = shortName
		self.longName       = longName
		self.hasValue       = hasValue
		self.enumValues     = enumValues
		self.isMandatory    = isMandatory
	}

	// String.componentsSeparatedByString can be used if Foundation is avaliable
	static func split(line: String, delim: Character) -> [String] {
		return line
		    .split(separator: delim, maxSplits: 5, omittingEmptySubsequences: false)
		    .map{String($0)}
	}

	static let WHITE_CHARS = " \t"
	static func trim(s: String) -> String {
		return String(s.filter{!WHITE_CHARS.contains($0)})
	}

	static func valueOf(define: String) throws -> CmdLineArgument {
		// componentsSeparatedByString is a Foundation function
		//let params = define.componentsSeparatedByString(",")
		let params = split(line: define, delim: ",")
		if params.count > 5 || params.count < 3 {
			throw ArgumentError.IllegalArgumentDefination(define)
		}

		// Validate short/long name & boolean values:
		// 	short name should starts with "-"
		//	long name should starts with "--"
		//  boolean values can be: true/false, Y/N, yes/no, T/F (case insensitive)
		let shortName = trim(s: params[0])
		let longName  = trim(s: params[1])

		if !shortName.hasPrefix("-") ||
		   shortName.hasPrefix("--") ||
		   !longName.hasPrefix("--") {
			throw ArgumentError.IllegalArgumentDefination(define)
		}

		var enumValues: Set<String> = []
		if params.count > 3 {
            if !trim(s: params[3]).isEmpty {
                for v in split(line: params[3], delim: "|") {
                    enumValues.insert(trim(s: v))
                }
            }
        }

        var isMandatory = false
        if params.count > 4 {
			do{
				isMandatory = try toBool(trim(s: params[4]))
			} catch {
				throw ArgumentError.IllegalArgumentDefination(define)
			}
        }

		var hasValue = false
		do {
			hasValue = try toBool(trim(s: params[2]))
		} catch {
			throw ArgumentError.IllegalArgumentDefination(define)
		}

		return CmdLineArgument(
		    shortName: shortName, longName: longName,
			hasValue: hasValue, enumValues: enumValues,
			isMandatory: isMandatory
		)
	}

	static let BOOL_TRUE  = ["TRUE", "Y", "YES", "T"]
	static let BOOL_FALSE = ["FALSE", "N", "NO", "F"]

	static func toBool(_ value: String) throws -> Bool {
		let uv = value.uppercased()
		for tv in BOOL_TRUE {
			if uv == tv {
				return true
			}
		}

		for fv in BOOL_FALSE {
			if uv == fv {
				return false
			}
		}

		throw ArgumentError.IllegalArgumentDefination(value);
	}

	func name() -> String {
		return shortName + "|" + longName;
	}

	func isEnumValue() -> Bool {
	    return !enumValues.isEmpty
	}

	func isSupplied() -> Bool {
		return value != nil
	}

	func getEnumValuesAsString() -> String {
		var buf = ""

		if !isEnumValue() {
			return buf
		}


		for v in enumValues {
			if buf.count > 0 {
				buf += "|"
			}

			buf += v
		}

		return buf
	}

	func validate() throws {
		if !hasValue && value != nil && !enumValues.isEmpty {
			throw ArgumentError.IllegalArgument("\(name()) is no value argument but set a value: \(value!)")
		}

		if isMandatory && !isSupplied() {
		    throw ArgumentError.IllegalArgument("\(name()) is mandatory argument, but has not been supplied")
		}

		if isEnumValue() && !enumValues.contains(value!) {
			throw ArgumentError.IllegalArgument("\(name()) value (\(value!)) is not permit, it can be: \(getEnumValuesAsString())")
		}
	}

	var description : String {
	    var evs = ""
	    for ev in enumValues {
	        if evs.count > 0 {
	            evs += "|"
	        }

	        evs += ev
	    }
	    return "\(shortName),\(longName),\(hasValue),\(evs)"
	}
}

/**
 * Encapsulate command line paring & validation logic
 *
 * @author Wayne Zhang
 */
class CmdLineArgumentParser : CustomStringConvertible {
	var shortNameMap: [String: CmdLineArgument] = [:]
	var longNameMap:  [String: CmdLineArgument] = [:]

	var hasParsed = false

	init(){
		// default constructor
	}

	init(argumentDefinations: [String]) throws {
		for defination in argumentDefinations {
			try defineArgument(argumentDefination: defination)
		}
	}

	convenience init(argumentDefinations: [String], args: [String]) throws {
		try self.init(argumentDefinations: argumentDefinations)

		try parse(args: args)
	}

	func defineArgument(argumentDefination: String) throws {
		let arg = try CmdLineArgument.valueOf(define: argumentDefination)

		shortNameMap[arg.shortName] = arg
		longNameMap[arg.longName] = arg
	}

	func parse(args: [String]) throws {
		hasParsed = true

		/*
		 * Swift GeneratorType, SequenceType and CollectionType
		 *
		 *    1. GeneratorType
		 *    	protocol GeneratorType {
		 *			typealias Element
		 *			mutating func next() -> Element?
		 * 	    }
		 *
		 *    2. SequenceType can generate() GeneratorType
		 *		protocol SequenceType {
		 *			typealias Generator: GeneratorType
		 *			func generate() -> Generator
		 *		}
		 *
		 *	  3. CollectionType is a SequenceType
		 *		protocol CollectionType : SequenceType
		 */
		var argGen = args.makeIterator()
		// skip first argument which is application name
		let _ = argGen.next()

		while let arg = argGen.next() {
			if String(arg.prefix(1)) == "-" {
				var argDef = shortNameMap[arg]

				if argDef == nil {
					argDef = longNameMap[arg]
				}

				if argDef == nil {
					throw ArgumentError.IllegalArgument("\(arg) not defined")
				}

				if argDef!.hasValue {
					if let nextArg = argGen.next() {
						if String(nextArg.prefix(1)) == "-" {
							throw ArgumentError.IllegalArgument("Wrong argument value '\(nextArg)' for argument \(arg)")
						}

						argDef!.value = nextArg
					}else {
						throw ArgumentError.IllegalArgument("Argument value not supplied for: \(arg)")
					}
				} else {
					argDef!.value = ""
				}
			} else {
				throw ArgumentError.IllegalArgument("\(arg) not defined")
			}
		}

		for arg in shortNameMap.values {
			if arg.isSupplied() {
				try arg.validate()
			} else if arg.isMandatory {
			    try arg.validate()
			}
		}
	}

	func isArgumentSupplied(arg: String) throws -> Bool {
		return try getArgumentValue(arg: arg) != nil
	}

	func getArgumentValue(arg: String) throws -> String? {
		if !hasParsed {
			throw ArgumentError.UsageError("Command line arguments hasn't been parsed.")
		}

		var argument = shortNameMap[arg]
		if argument == nil {
			argument = longNameMap[arg]
		}

		if argument == nil {
			throw ArgumentError.IllegalArgument("Argument \(arg) not defined")
		}

		return argument!.value
	}

	var description : String {
	    var buf = ""
	    for arg in shortNameMap.values {
	        buf += "\(arg)\n"
	    }

	    return buf
	}
}

// Swift 3 core libaries supports Foundation on Linux now!
import Foundation // OSX/iOS is Foundation
//import Glibc // Liux/Unix is Glibc

// Error pattern matching
public func ~=(lhs: Error, rhs: Error) -> Bool {
	return lhs._domain == rhs._domain &&
		   lhs._code == rhs._code
}

/*
extension ArgumentError : Equatable {}

public func ==(lhs: ArgumentError, rhs: ArgumentError) -> Bool {
	switch(lhs, rhs) {
		case (.IllegalArgument(let lmsg), .IllegalArgument(let rmsg)):
			return lmsg == rmsg
		case (.IllegalArgumentDefination(let lmsg), .IllegalArgumentDefination(let rmsg)):
			return lmsg == rmsg
		case (.UsageError(let lmsg), .UsageError(let rmsg)):
			return lmsg == rmsg
		default:
			return lhs._domain == rhs._domain &&
				   lhs._code == rhs._code
	}
}*/

class TestCase {
	func XCTFail(msg: String){
		print(msg)
		exit(0)
	}

	// In Swift 3, there is not possible to define an @autoclosure and non @autoclosure method
	// at same time - it compiles but @autoclosure version will be always used with trailing closure.
	// Trailing closure must be used to support multiple expressions, so alwways using trailing closure,
	// even for online line expression.
	func AssertThrow<R>(expectedError: Error, _ closure: @autoclosure () throws -> R) -> () {
		do {
			//print("Auto closure to be executed...")
			try closure()

			XCTFail(msg: "Expected error \(expectedError) but success")
		} catch expectedError {
			// Error expected
		} catch {
			XCTFail(msg: "Error expected \(expectedError) but caught: \(error)")
		}
	}

	// non-autoclosure version
	/*
	func AssertThrow<R>(expectedError: Error, _ closure: () throws -> R) -> () {
		do {
			//print("Closure to be executed...")
			try closure()

			XCTFail(msg: "Expected error \(expectedError) but success")
		} catch expectedError {
			// Error expected
		} catch {
			XCTFail(msg: "Error expected \(expectedError) but caught: \(error)")
		}
	}*/
}

class MyTestCase : TestCase {
	let parser = CmdLineArgumentParser()

	func run() {
		do{
			try parser.defineArgument(argumentDefination: "-a,--action, true, create|update|delete")
			try parser.defineArgument(argumentDefination: "-v, --verbose, false")
		}catch {
			XCTFail(msg: "Initialize parser failed")
		}


		testValid()
		testNoArgumentValueSupplied()
		testWrongArg()
		testWrongArgValue()
		testWrongArgValue4NoValueArg()
		testGetUndefinedArgumentValue()
		testNoParseCalled()
		testInvalidArgumentDefination()
		testInvalidArgumentDefinationBoolValue()
	}

	func testValid() {
		do{
			try parser.parse(args: ["CmdLineArgumentParser", "-v", "-a", "create"])
		}catch{
			XCTFail(msg: "Error unexpected: \(error)")
		}
	}

	func testNoArgumentValueSupplied() {
		/*
		do{
			try parser.parse(args: ["CmdLineArgumentParser", "-a"])

			XCTFail(msg: "Error expected")
		}catch ArgumentError.IllegalArgument{
			// expected
		}catch {
			XCTFail(msg: "Excpected ArgumentError, but got \(error)")
		}*/

		AssertThrow(expectedError: ArgumentError.IllegalArgument("foo"),
			try parser.parse(args: ["CmdLineArgumentParser", "-a"])
		)
	}

	func testWrongArg() {
		// new implementation
		AssertThrow(expectedError: ArgumentError.IllegalArgument("-foo not defined"),
			try parser.parse(args: ["App Name", "--foo", "bar", "-v"])
		)
	}

	func testWrongArgValue(){
		AssertThrow(expectedError: ArgumentError.IllegalArgument("Wrong argument value 'drop' for argument --action"),
			try parser.parse(args: ["App Name", "-v", "--action", "drop"])
		)
	}

	func testWrongArgValue4NoValueArg(){
		AssertThrow(expectedError: ArgumentError.IllegalArgument("bad not defined"),
			try parser.parse(args: ["App Name", "-v", "bad", "--action", "drop"])
		)
	}

	func testGetUndefinedArgumentValue(){
		do{
			try parser.parse(args: ["App Name", "-a", "create", "-v"]);
		}catch {
			// ignore
		}

		AssertThrow(expectedError: ArgumentError.IllegalArgument("Argument -b not defined"),
			try parser.getArgumentValue(arg: "-b")
		)
	}

	func testNoParseCalled(){
		let parser = CmdLineArgumentParser()
		do{
			try parser.defineArgument(argumentDefination: "-a,--action,true,create|update|delete")
			try parser.defineArgument(argumentDefination: "-v,--verbose,false,")
		}catch {
			// ignore
		}

		AssertThrow(expectedError: ArgumentError.UsageError("Command line arguments hasn't been parsed."),
			try parser.getArgumentValue(arg: "-a")
		)
	}

	func testInvalidArgumentDefination(){
		let argDef = "-a--action,true,create|update|delete"
		let parser = CmdLineArgumentParser()

		AssertThrow(expectedError: ArgumentError.IllegalArgumentDefination(argDef),
			try parser.defineArgument(argumentDefination: argDef)
		)
	}

	func testInvalidArgumentDefinationBoolValue(){
		let argDef = "-a,--action,bool?,create|update|delete"
		let parser = CmdLineArgumentParser()

		AssertThrow(expectedError: ArgumentError.IllegalArgumentDefination(argDef),
			try parser.defineArgument(argumentDefination: argDef)
		)
	}
}

class ExampleApp {
	init() {

	}

	func usage() {
		print("Usage: CmdLineParser [-h|--help] [-v|--verbose] [-a|action create|delete|update]")
	}

	func run() {
		let parser = CmdLineArgumentParser()

		do{
			try parser.defineArgument(argumentDefination: "-v,--verbose,false,")
			try parser.defineArgument(argumentDefination: "-h,--help,false,")
			try parser.defineArgument(argumentDefination: "-a,--action,true,create|update|delete")
			try parser.parse(args: CommandLine.arguments)

			// print argument defination
			print(parser)

			let av = try parser.getArgumentValue(arg: "-a") ?? "not supplied";
			let vv = try parser.isArgumentSupplied(arg: "-v")
			let hv = try parser.isArgumentSupplied(arg: "-h")
			print("-a|--action: \(av)")
			print("-v|--verbose: \(vv)")
			print("-h|--help: \(hv)")
		}catch ArgumentError.IllegalArgumentDefination(let msg){
			print("\(msg)")

			usage()
		}catch ArgumentError.IllegalArgument(let msg){
			print("\(msg)")

			usage()
		}catch ArgumentError.UsageError(let msg) {
			print("\(msg)")

			usage()
		} catch {
			print("Unkown error: \(error)")

			usage();
		}

	}
}

let test = MyTestCase()
test.run()

// run example application if test passed
let example = ExampleApp()
example.run()
