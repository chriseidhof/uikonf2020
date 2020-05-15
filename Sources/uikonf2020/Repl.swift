import LineNoise
import Template

struct PrettyError: Error {
    var string = ""
}

func parse(_ input: String) throws -> AnnotatedExpression {
    var e = PrettyError()
    do {
        return try input.parse()
    } catch let err as ParseError {
        let lineRange = input.lineRange(for: err.position..<err.position)
        
        print("", to: &e.string)
        print(input, to: &e.string) // todo use lineRange
        let distance = input.distance(from: lineRange.lowerBound, to: err.position)
        print(String(repeating: " ", count: distance) + "^", to: &e.string)
        print(err.reason, to: &e.string)
        throw e
    }
}

func repl() {
    let ln = LineNoise()
    while true {
        var input: String = ""
        do {
            input = try ln.getLine(prompt: "> ")
            ln.addHistory(input)
            print("")
            if input == "gui" {
                run(view: TreeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity))
            }
            let parsed = try input.parse()
            let result = try parsed.run().0.get()
            print(result.pretty)
        } catch let e as ParseError {
            let lineRange = input.lineRange(for: e.position..<e.position)
            print("")
            print(input) // todo use lineRange
            let distance = input.distance(from: lineRange.lowerBound, to: e.position)
            print(String(repeating: " ", count: distance) + "^")
            print(e.reason)
        } catch let e as EvaluationError {
            let lineRange = input.lineRange(for: e.position.startIndex..<e.position.startIndex)
            print("")
            print(input) // todo use lineRange
            let distance = input.distance(from: lineRange.lowerBound, to: e.position.startIndex)
            print(String(repeating: " ", count: distance) + "^")
            print(e.reason)
        } catch LinenoiseError.CTRL_C {
            break
        } catch LinenoiseError.EOF {
            break
        } catch {
            dump(error)
        }
    }
}
