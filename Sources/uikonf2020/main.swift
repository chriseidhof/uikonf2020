import LineNoise
import Template

func repl() {
    let ln = LineNoise()

    while true {
//        print("> ", terminator: "")
        var input: String = ""
        do {
            input = try ln.getLine(prompt: "> ")
            ln.addHistory(input)
            print("")
            let parsed = try input.parse()
            let result = try parsed.run()
            print(result)
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

repl()
