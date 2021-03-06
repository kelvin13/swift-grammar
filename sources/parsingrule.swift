/// A structured parsing rule.
public 
protocol ParsingRule 
{
    /// The index type of the ``ParsingInput.source`` this rule expects.
    /// 
    /// Parsing rules must be associated with a source location type because 
    /// some applications may wish to store these indices in the returned 
    /// ``Construction``s. If the source location type were not fixed, then 
    /// different calls to ``parse(_:)`` could potentially return constructions
    /// of varying types, which would require additional abstraction, which would 
    /// be inefficient.
    /// 
    /// >   Tip: 
    ///     Implementations can satisfy this requirement with generics, allowing 
    ///     parsing rules to be reused for different input types. 
    associatedtype Location
    /// The element type of the ``ParsingInput.source`` this rule expects.
    associatedtype Terminal 
    /// The type of the constructions produced by a successful application of this 
    /// parsing rule.
    /// 
    /// Implementations should not report failure through an ``Optional`` 
    /// construction type. Instead, implementations should [`throw`]() an ``Error``, 
    /// which allows the library to perform appropriate cleanup and backtracking.
    associatedtype Construction
    
    /// Attempts to parse an instance of ``Construction`` from the given 
    /// parsing input.
    ///
    /// The implementation is not required to clean up the state of the `input`
    /// upon throwing an error; this is handled by the library.
    /// 
    /// Implementations *should* interact with the given ``ParsingInput`` by 
    /// calling its methods and subscripts. Don’t overwrite the [`inout`]() binding or its 
    /// mutable stored properties (``ParsingInput/.index`` and ``ParsingInput/.diagnostics``)
    /// unless you really know what you’re doing.
    /// 
    /// >   Tip: 
    ///     Mutating `input` does *not* invalidate its indices. You can always 
    ///     store an ``ParsingInput/.index`` and dereference it later, as long 
    ///     as you do not overwrite the [`inout`]() binding elsewhere.
    static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Construction
    where   Diagnostics:ParsingDiagnostics, 
            Diagnostics.Source.Index == Location, 
            Diagnostics.Source.Element == Terminal
}
// these extensions are mainly useful when defined as part of a tuple rule.
// otherwise, the overloads in the previous section of code should be preferred
extension Optional:ParsingRule where Wrapped:ParsingRule 
{
    public 
    typealias Location  = Wrapped.Location
    public 
    typealias Terminal  = Wrapped.Terminal 
    
    @inlinable public static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> Wrapped.Construction?
    where   Diagnostics:ParsingDiagnostics,
            Diagnostics.Source.Index == Location,
            Diagnostics.Source.Element == Terminal
    {
        // will choose non-throwing overload, so no infinite recursion will occur
        input.parse(as: Wrapped?.self)
    }
} 
extension Array:ParsingRule where Element:ParsingRule
{
    public
    typealias Location = Element.Location
    public
    typealias Terminal = Element.Terminal 
    
    @inlinable public static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> [Element.Construction]
    where   Diagnostics:ParsingDiagnostics,
            Diagnostics.Source.Index == Location,
            Diagnostics.Source.Element == Terminal
    {
        input.parse(as: Element.self, in: [Element.Construction].self)
    }
}
// builtin tools
extension Grammar 
{
    public
    enum End<Location, Terminal>:ParsingRule 
    {
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws 
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            if let _:Terminal = input.next() 
            {
                throw Expected<Never>.init()
            }
        }
    }
    public 
    enum Discard<Rule>:ParsingRule 
        where   Rule:ParsingRule, Rule.Construction == Void
    {
        public 
        typealias Location = Rule.Location
        public 
        typealias Terminal = Rule.Terminal 
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            input.parse(as: Rule.self, in: Void.self)
        }
    }
    public 
    enum Collect<Rule, Construction>:ParsingRule 
        where   Rule:ParsingRule, Rule.Construction == Construction.Element,
                Construction:RangeReplaceableCollection
    {
        public 
        typealias Location = Rule.Location
        public 
        typealias Terminal = Rule.Terminal 
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> Construction
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            input.parse(as: Rule.self, in: Construction.self)
        }
    }
    public 
    enum Reduce<Rule, Construction>:ParsingRule 
        where   Rule:ParsingRule, Rule.Construction == Construction.Element,
                Construction:RangeReplaceableCollection
    {
        public 
        typealias Location = Rule.Location
        public 
        typealias Terminal = Rule.Terminal 
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Construction
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            var vector:Construction = .init()
                vector.append(try input.parse(as: Rule.self))
            while let next:Rule.Construction = input.parse(as: Rule?.self)
            {
                vector.append(next)
            }
            return vector
        }
    }
    public 
    enum Join<Rule, Separator, Construction>:ParsingRule
        where   Rule:ParsingRule, Separator:ParsingRule,
                Rule.Location == Separator.Location, 
                Rule.Terminal == Separator.Terminal, 
                Separator.Construction == Void, 
                Rule.Construction == Construction.Element, 
                Construction:RangeReplaceableCollection
    {
        public 
        typealias Terminal = Rule.Terminal
        public 
        typealias Location = Rule.Location
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Construction
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            var vector:Construction = .init()
                vector.append(try input.parse(as: Rule.self))
            while let (_, next):(Void, Rule.Construction)  = try? input.parse(as: (Separator, Rule).self)
            {
                vector.append(next)
            }
            return vector
        }
    }
    public 
    enum Pad<Rule, Padding>:ParsingRule
        where   Rule:ParsingRule, Padding:ParsingRule, 
                Rule.Location == Padding.Location,
                Rule.Terminal == Padding.Terminal, 
                Padding.Construction == Void
    {
        public 
        typealias Terminal = Rule.Terminal
        public 
        typealias Location = Rule.Location
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Rule.Construction
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, 
                Diagnostics.Source.Element == Terminal
        {
            input.parse(as: Padding.self, in: Void.self)
            let construction:Rule.Construction = try input.parse(as: Rule.self) 
            input.parse(as: Padding.self, in: Void.self)
            return construction
        }
    }
}
