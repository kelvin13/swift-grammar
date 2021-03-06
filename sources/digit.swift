public
protocol DigitRule:TerminalRule where Construction:BinaryInteger
{    
    static 
    var radix:Construction 
    {
        get 
    }
}

extension Grammar 
{
    public 
    enum NaturalDecimalDigit<Location, Terminal, Construction>:TerminalRule
        where Terminal:BinaryInteger, Construction:BinaryInteger
    {
        @inlinable public static 
        func parse(terminal:Terminal) -> Construction? 
        {
            guard 0x31 ... 0x39 ~= terminal 
            else 
            {
                return nil 
            }
            return .init(terminal - 0x30)
        }
    }
    public 
    enum DecimalDigit<Location, Terminal, Construction>:DigitRule 
        where Terminal:BinaryInteger, Construction:BinaryInteger
    {
        @inlinable public static 
        var radix:Construction 
        {
            10
        }
        @inlinable public static 
        func parse(terminal:Terminal) -> Construction? 
        {
            guard 0x30 ... 0x39 ~= terminal 
            else 
            {
                return nil 
            }
            return .init(terminal - 0x30)
        }
    }
    public 
    enum HexDigit<Location, Terminal, Construction>:DigitRule 
        where Terminal:BinaryInteger, Construction:BinaryInteger 
    {
        @inlinable public static 
        var radix:Construction 
        {
            16
        }
        @inlinable public static 
        func parse(terminal:Terminal) -> Construction?
        {
            switch terminal 
            {
            case 0x30 ... 0x39: return Construction.init(terminal - 0x30)
            case 0x61 ... 0x66: return Construction.init(terminal +   10 - 0x61)
            case 0x41 ... 0x46: return Construction.init(terminal +   10 - 0x41)
            default:            return nil
            }
        }
        
        public 
        enum Lowercase:DigitRule
        {
            @inlinable public static 
            var radix:Construction 
            {
                16
            }
            @inlinable public static 
            func parse(terminal:Terminal) -> Construction?
            {
                switch terminal 
                {
                case 0x30 ... 0x39: return Construction.init(terminal - 0x30)
                case 0x61 ... 0x66: return Construction.init(terminal +   10 - 0x61)
                default:            return nil
                }
            }
        }
    }
}
extension Grammar
{
    public 
    enum NaturalDecimalDigitScalar<Location, Construction>:TerminalRule where Construction:BinaryInteger 
    {
        public 
        typealias Terminal = Unicode.Scalar 
        
        @inlinable public static 
        func parse(terminal:Unicode.Scalar) -> Construction?
        {
            "1" ... "9" ~= terminal ? 
                Construction.init(terminal.value - ("0" as Unicode.Scalar).value) : nil
        }
    }
    public 
    enum DecimalDigitScalar<Location, Construction>:DigitRule where Construction:BinaryInteger 
    {
        public 
        typealias Terminal = Unicode.Scalar 
        
        @inlinable public static 
        var radix:Construction 
        {
            10
        }
        @inlinable public static 
        func parse(terminal:Unicode.Scalar) -> Construction?
        {
            "0" ... "9" ~= terminal ? 
                Construction.init(terminal.value - ("0" as Unicode.Scalar).value) : nil
        }
    }
    public 
    enum HexDigitScalar<Location, Construction>:DigitRule where Construction:BinaryInteger 
    {
        public 
        typealias Terminal = Unicode.Scalar 
        
        @inlinable public static 
        var radix:Construction 
        {
            16
        }
        @inlinable public static 
        func parse(terminal:Unicode.Scalar) -> Construction?
        {
            switch terminal 
            {
            case "0" ... "9":
                return Construction.init(terminal.value      - ("0" as Unicode.Scalar).value)
            case "a" ... "f":
                return Construction.init(terminal.value + 10 - ("a" as Unicode.Scalar).value)
            case "A" ... "F":
                return Construction.init(terminal.value + 10 - ("A" as Unicode.Scalar).value)
            default:
                return nil
            }
        }
        
        public 
        enum Lowercase:DigitRule
        {
            public 
            typealias Terminal = Unicode.Scalar 
            
            @inlinable public static 
            var radix:Construction 
            {
                16
            }
            @inlinable public static 
            func parse(terminal:Unicode.Scalar) -> Construction?
            {
                switch terminal 
                {
                case "0" ... "9":
                    return Construction.init(terminal.value      - ("0" as Unicode.Scalar).value)
                case "a" ... "f":
                    return Construction.init(terminal.value + 10 - ("a" as Unicode.Scalar).value)
                default:
                    return nil
                }
            }
        }
    }
}

extension Grammar 
{
    @frozen public
    struct IntegerOverflowError<T>:Error, CustomStringConvertible 
    {
        // don???t mark this @inlinable, since we generally don???t expect to 
        // recover from this
        public 
        init()
        {
        }
        public
        var description:String 
        {
            "parsed value overflows integer type '\(T.self)'"
        }
    }
    
    public
    typealias UnsignedIntegerLiteral<Digit> = UnsignedNormalizedIntegerLiteral<Digit, Digit>
    where Digit:DigitRule, Digit.Construction:FixedWidthInteger
    
    public
    enum UnsignedNormalizedIntegerLiteral<First, Next>:ParsingRule
    where   First:ParsingRule, Next:DigitRule, Next.Construction:FixedWidthInteger, 
            First.Construction == Next.Construction, 
            First.Location == Next.Location, 
            First.Terminal == Next.Terminal
    {
        public
        typealias Location = First.Location
        public
        typealias Terminal = First.Terminal
        
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Next.Construction
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            var value:Next.Construction = try input.parse(as: First.self)
            while let remainder:Next.Construction = input.parse(as: Next?.self)
            {
                guard   case (let shifted, false) = value.multipliedReportingOverflow(by: Next.radix), 
                        case (let refined, false) = shifted.addingReportingOverflow(remainder)
                else 
                {
                    throw IntegerOverflowError<Next.Construction>.init()
                }
                value = refined
            }
            return value
        }
    }
}
