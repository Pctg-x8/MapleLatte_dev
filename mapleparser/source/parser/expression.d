module mlfe.mapleparser.parser.expression;

import mlfe.mapleparser.parser.base;
import mlfe.mapleparser.parser.symbol;
import mlfe.mapleparser.parser.type;
import mlfe.mapleparser.parser.statement;
import mlfe.mapleparser.parser.exceptions;
import mlfe.mapleparser.lexer.token;
import std.algorithm, std.range;

/// Expression = TriExpression [AssignOps Expression]
public static class Expression
{
	public static immutable canParse = TriExpression.canParse;
	public static TokenList drops(TokenList input)
	{
		return TriExpression.drops(input)
			.thenIf!(a => AssignOps.canParse(a), a => Expression.drops(AssignOps.drops(a)));
	}
	public static TokenList parse(TokenList input)
	{
		auto in2_tx = TriExpression.parse(input);
		if(AssignOps.canParse(in2_tx))
		{
			return Expression.parse(AssignOps.parse(in2_tx));
		}
		else return in2_tx;
	}
}
/// ExpressionList = Expression ("," Expression)*
public static class ExpressionList
{
	public static immutable canParse = Expression.canParse;
	public static TokenList drops(TokenList input)
	{
		static TokenList loop(TokenList input)
		{
			return input.front.type == TokenType.Comma ? loop(Expression.drops(input.dropOne)) : input;
		}
		return loop(Expression.drops(input));
	}
	public static TokenList parse(TokenList input)
	{
		static TokenList loop(TokenList input)
		{
			return input.front.type == TokenType.Comma ? loop(Expression.parse(input.dropOne)) : input;
		}
		
		return loop(Expression.parse(input));
	}
}

/// AssignOps(Set of tokens) = "=" | "+=" | "-=" | "*=" | "/=" | "%="
///			| "&=" | "|=" | "^=" | ">>=" | "<<="
public static class AssignOps
{
	public static bool canParse(TokenList input)
	{
		return [TokenType.Equal, TokenType.Plus_Equal, TokenType.Minus_Equal, TokenType.Asterisk_Equal,
			TokenType.Slash_Equal, TokenType.Percent_Equal, TokenType.Ampasand_Equal, TokenType.VerticalLine_Equal,
			TokenType.Accent_Equal, TokenType.LeftAngleBracket2_Equal, TokenType.RightAngleBracket2_Equal]
			.any!(a => a == input.front.type);
	}
	public static TokenList drops(TokenList input) { return canParse(input) ? input.dropOne : input; }
	public static TokenList parse(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.Equal: return input.dropOne;
		case TokenType.Plus_Equal: return input.dropOne;
		case TokenType.Minus_Equal: return input.dropOne;
		case TokenType.Asterisk_Equal: return input.dropOne;
		case TokenType.Slash_Equal: return input.dropOne;
		case TokenType.Percent_Equal: return input.dropOne;
		case TokenType.Ampasand_Equal: return input.dropOne;
		case TokenType.VerticalLine_Equal: return input.dropOne;
		case TokenType.Accent_Equal: return input.dropOne;
		case TokenType.LeftAngleBracket2_Equal: return input.dropOne;
		case TokenType.RightAngleBracket2_Equal: return input.dropOne;
		default: throw new ParseException("No match tokens found", input.front.at);
		}
	}
}

/// TriExpression = LogicalExpression ["?" TriExpression ":" TriExpression]
public static class TriExpression
{
	public static immutable canParse = LogicalExpression.canParse;
	public static TokenList drops(TokenList input)
	{
		return LogicalExpression.drops(input).thenIf!(
			a => a.front.type == TokenType.Hatena, (a)
			{
				auto in2 = TriExpression.drops(a.dropOne);
				if(in2.front.type != TokenType.Colon) return input;
				return TriExpression.drops(in2.dropOne);
			}
		);
	}
	public static TokenList parse(TokenList input)
	{
		auto in2 = LogicalExpression.parse(input);
		if(in2.front.type == TokenType.Hatena)
		{
			return TriExpression.parse(TriExpression.parse(in2.dropOne).consumeToken!(TokenType.Colon));
		}
		else return in2;
	}
}
/// BinaryExpression = ContainedRule (Operators[0] ContainedRule | ...)*
public static class BinaryExpression(ContainedRule, Operators...)
{
	static if(is(typeof(ContainedRule.canParse) == function))
		public static immutable canParse = &ContainedRule.canParse;
	else
		public static immutable canParse = ContainedRule.canParse;
	public static TokenList drops(TokenList input)
	{
		static TokenList loop(TokenList input)
		{
			foreach(op; Operators)
			{
				if(input.front.type == op) return loop(ContainedRule.drops(input.dropOne));
			}
			return input;
		}
		return loop(ContainedRule.drops(input));
	}
	public static TokenList parse(TokenList input)
	{
		static TokenList loop(TokenList input)
		{
			foreach(op; Operators)
			{
				if(input.front.type == op) return loop(ContainedRule.parse(input.dropOne));
			}
			return input;
		}
		return loop(ContainedRule.parse(input));
	}
}
/// LogicalExpression = CompareExpression ("&&" CompareExpression | "||" CompareExpression)*
alias LogicalExpression = BinaryExpression!(CompareExpression, TokenType.Ampasand2, TokenType.VerticalLine2);
/// CompareExpression = ShiftExpression ("==" ShiftExpression | "!=" ShiftExpression
///		| "<" ShiftExpression | ">" ShiftExpression | "<=" ShiftExpression | ">=" ShiftExpression)*
alias CompareExpression = BinaryExpression!(ShiftExpression, TokenType.Equal2, TokenType.Exclamation_Equal,
	TokenType.LeftAngleBracket, TokenType.RightAngleBracket,
	TokenType.LeftAngleBracket_Equal, TokenType.RightAngleBracket_Equal);
/// ShiftExpression = BitExpression ("<<" BitExpression | ">>" BitExpression)*
alias ShiftExpression = BinaryExpression!(BitExpression, TokenType.LeftAngleBracket2, TokenType.RightAngleBracket2);
/// BitExpression = AddExpression ("&" AddExpression | "|" AddExpression | "^" AddExpression)*
alias BitExpression = BinaryExpression!(AddExpression, TokenType.Ampasand, TokenType.VerticalLine, TokenType.Accent);
/// AddExpression = MultiExpression ("+" MultiExpression | "-" MultiExpression)*
alias AddExpression = BinaryExpression!(MultiExpression, TokenType.Plus, TokenType.Minus);
/// MultiExpression = PrefixExpression ("*" PrefixExpression | "/" PrefixExpression | "%" PrefixExpression)*
alias MultiExpression = BinaryExpression!(PrefixExpression, TokenType.Asterisk, TokenType.Slash, TokenType.Percent);

/// PrefixExpression = "++" PrefixExpression | "--" PrefixExpression | "**" PrefixExpression
///		| "+" PrefixExpression | "-" PrefixExpression | PostfixExpression
public static class PrefixExpression
{
	public static bool canParse(TokenList input)
	{
		return PostfixExpression.canParse(input) || 
			[TokenType.Plus2, TokenType.Plus, TokenType.Minus2, TokenType.Minus, TokenType.Asterisk2]
			.any!(a => a == input.front.type);
	}
	public static TokenList drops(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.Plus2: case TokenType.Minus2: case TokenType.Plus: case TokenType.Minus: case TokenType.Asterisk2:
			return PrefixExpression.drops(input.dropOne);
		default: return PostfixExpression.drops(input);
		}
	}
	public static TokenList parse(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.Plus2: return PrefixExpression.parse(input.dropOne);
		case TokenType.Minus2: return PrefixExpression.parse(input.dropOne);
		case TokenType.Asterisk2: return PrefixExpression.parse(input.dropOne);
		case TokenType.Plus: return PrefixExpression.parse(input.dropOne);
		case TokenType.Minus: return PrefixExpression.parse(input.dropOne);
		default: return PostfixExpression.parse(input);
		}
	}
}

/// PostfixExpression = PrimaryExpression ("++" | "--" | "**" | "(" [ExpressionList] ")" | "[" Expression "]" | "." TemplateInstance)*
public static class PostfixExpression
{
	public static immutable canParse = &PrimaryExpression.canParse;
	public static TokenList drops(TokenList input)
	{
		static TokenList loop(TokenList input)
		{
			switch(input.front.type)
			{
			case TokenType.Plus2: case TokenType.Minus2: case TokenType.Asterisk2:
				return loop(input.dropOne);
			case TokenType.OpenParenthese:
				if(input.dropOne.front.type == TokenType.CloseParenthese)
				{
					return loop(input.drop(2));
				}
				else
				{
					auto in2 = ExpressionList.drops(input.dropOne);
					if(in2.front.type != TokenType.CloseParenthese) return input;
					return loop(in2.dropOne);
				}
			case TokenType.OpenBracket:
			{
				auto in2 = Expression.drops(input.dropOne);
				if(in2.front.type != TokenType.CloseBracket) return input;
				else return loop(in2.dropOne);
			}
			case TokenType.Period:
				return loop(TemplateInstance.drops(input.dropOne));
			default: return input;
			}
		}
		return loop(PrimaryExpression.drops(input));
	}
	public static TokenList parse(TokenList input)
	{
		static TokenList loop(TokenList input)
		{
			switch(input.front.type)
			{
			case TokenType.Plus2: return loop(input.dropOne);
			case TokenType.Minus2: return loop(input.dropOne);
			case TokenType.Asterisk2: return loop(input.dropOne);
			case TokenType.OpenParenthese:
				if(input.dropOne.front.type == TokenType.CloseParenthese)
				{
					return loop(input.drop(2));
				}
				else
				{
					return loop(ExpressionList.parse(input.dropOne).consumeToken!(TokenType.CloseParenthese));
				}
			case TokenType.OpenBracket:
				return loop(Expression.parse(input.dropOne).consumeToken!(TokenType.CloseBracket));
			case TokenType.Period:
				return loop(TemplateInstance.parse(input.dropOne));
			default: return input;
			}
		}
		
		return loop(PrimaryExpression.parse(input));
	}
}

/// PrimaryExpression = Literal | SpecialLiteral | ComplexLiteral
///		| TemplateInstance | "." TemplateInstance | "global" "." TemplateInstance"
///		| NewExpression | SwitchExpression | "(" Expression ")"
public static class PrimaryExpression
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.OpenParenthese || input.front.type == TokenType.Period
			|| input.front.type == TokenType.Global || input.front.type == TokenType.New
			|| input.front.type == TokenType.Switch
			|| Literal.canParse(input) || SpecialLiteral.canParse(input) || TemplateInstance.canParse(input)
			|| ComplexLiteral.canParse(input);
	}
	public static TokenList drops(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.OpenParenthese:
		{
			auto in2 = Expression.drops(input.dropOne);
			if(in2.front.type != TokenType.CloseParenthese) return input;
			else return in2.dropOne;
		}
		case TokenType.Period: return TemplateInstance.drops(input.dropOne);
		case TokenType.Global:
		{
			if(input.dropOne.front.type != TokenType.Period) return input;
			return TemplateInstance.drops(input.drop(2));
		}
		case TokenType.New: return NewExpression.drops(input);
		case TokenType.Switch: return SwitchExpression.drops(input);
		default: break;
		}
		if(TemplateInstance.canParse(input)) return TemplateInstance.drops(input);
		if(Literal.canParse(input)) return Literal.drops(input);
		if(SpecialLiteral.canParse(input)) return SpecialLiteral.drops(input);
		if(ComplexLiteral.canParse(input)) return ComplexLiteral.drops(input);
		return input;
	}
	public static TokenList parse(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.OpenParenthese: return Expression.parse(input.dropOne).consumeToken!(TokenType.CloseParenthese);
		case TokenType.Period: return TemplateInstance.parse(input.dropOne);
		case TokenType.Global: return TemplateInstance.parse(input.dropOne.consumeToken!(TokenType.Period));
		case TokenType.New: return NewExpression.parse(input);
		case TokenType.Switch: return SwitchExpression.parse(input);
		default: break;
		}
		if(TemplateInstance.canParse(input)) return TemplateInstance.parse(input);
		if(Literal.canParse(input)) return Literal.parse(input);
		if(SpecialLiteral.canParse(input)) return SpecialLiteral.parse(input);
		if(ComplexLiteral.canParse(input)) return ComplexLiteral.parse(input);
		throw new ParseException("No match rules found", input.front.at);
	}
}

/// Literal(Set of Tokens) = [NumericLiteral] | [FloatLiteral] | [DoubleLiteral] | [StringLiteral] | [CharacterLiteral]
///			| [LongLiteral] | [UlongLiteral]
public static class Literal
{
	public static bool canParse(TokenList input)
	{
		return [TokenType.NumericLiteral, TokenType.FloatLiteral, TokenType.DoubleLiteral,
			TokenType.StringLiteral, TokenType.CharacterLiteral, TokenType.LongLiteral, TokenType.UlongLiteral]
			.any!(a => a == input.front.type);
	}
	public static TokenList drops(TokenList input)
	{
		return canParse(input) ? input.dropOne : input;
	}
	public static TokenList parse(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.NumericLiteral: return input.dropOne;
		case TokenType.FloatLiteral: return input.dropOne;
		case TokenType.DoubleLiteral: return input.dropOne;
		case TokenType.StringLiteral: return input.dropOne;
		case TokenType.CharacterLiteral: return input.dropOne;
		case TokenType.LongLiteral: return input.dropOne;
		case TokenType.UlongLiteral: return input.dropOne;
		default: throw new ParseException("No match tokens found", input.front.at);
		}
	}
}

/// SpecialLiteral = "this" | "super" | "true" | "false"
public static class SpecialLiteral
{
	public static bool canParse(TokenList input)
	{
		return [TokenType.This, TokenType.Super, TokenType.True, TokenType.False].any!(a => a == input.front.type);
	}
	public static TokenList drops(TokenList input)
	{
		return canParse(input) ? input.dropOne : input;
	}
	public static TokenList parse(TokenList input)
	{
		switch(input.front.type)
		{
		case TokenType.This: return input.dropOne;
		case TokenType.Super: return input.dropOne;
		case TokenType.True: return input.dropOne;
		case TokenType.False: return input.dropOne;
		default: throw new ParseException("No match tokens found", input.front.at);
		}
	}
}

/// ComplexLiteral = "[" [ExpressionList] "]"
public static class ComplexLiteral
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.OpenBracket;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.front.type != TokenType.OpenBracket) return input;
		if(input.dropOne.front.type == TokenType.CloseBracket) return input.drop(2);
		auto in2 = ExpressionList.drops(input.dropOne);
		if(in2.front.type != TokenType.CloseBracket) return input;
		return in2.dropOne;
	}
	public static TokenList parse(TokenList input)
	{
		auto in2 = input.consumeToken!(TokenType.OpenBracket);
		if(in2.front.type == TokenType.CloseBracket) return in2.dropOne;
		else return ExpressionList.parse(in2).consumeToken!(TokenType.CloseBracket);
	}
}

/// NewExpression = "new" Type ("[" [Expression] "]")* ["(" [ExpressionList] ")"]
public static class NewExpression
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.New;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.front.type != TokenType.New) return input;
		return Type.drops(input.dropOne)
			.thenLoop!(a => a.front.type == TokenType.OpenBracket, (a)
			{
				if(a.dropOne.front.type == TokenType.CloseBracket) return a.drop(2);
				else
				{
					return Expression.drops(a.dropOne)
						.then!(b => b.front.type == TokenType.CloseBracket ? b.dropOne : a);
				}
			})
			.thenIf!(a => a.front.type == TokenType.OpenParenthese, (a)
			{
				return a.dropOne.front.type == TokenType.CloseParenthese
					? a.drop(2)
					: ExpressionList.drops(a.dropOne)
						.then!(b => b.front.type == TokenType.CloseParenthese ? b.dropOne : a);
			});
	}
	public static TokenList parse(TokenList input)
	{
		return input.consumeToken!(TokenType.New)
			.then!(Type.parse)
			.thenLoop!(a => a.front.type == TokenType.OpenBracket, (a)
			{
				return a.dropOne.front.type == TokenType.CloseBracket
					? a.drop(2)
					: Expression.parse(a.dropOne).consumeToken!(TokenType.CloseBracket);
			})
			.thenIf!(a => a.front.type == TokenType.OpenParenthese, (a)
			{
				return a.dropOne.front.type == TokenType.CloseParenthese
					? a.drop(2)
					: ExpressionList.parse(a.dropOne).consumeToken!(TokenType.CloseParenthese);
			});
	}
}

/// SwitchExpression = "switch" "(" Expression ")" "{" (CaseClause | DefaultClause)* "}"
public static class SwitchExpression
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.Switch;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.front.type != TokenType.Switch) return input;
		if(input.dropOne.front.type != TokenType.OpenParenthese) return input;
		auto ine = Expression.drops(input.drop(2));
		if(ine.front.type != TokenType.CloseParenthese) return input;
		if(ine.dropOne.front.type != TokenType.OpenBrace) return input;
		auto in3 = ine.drop(2)
			.thenLoop!(a => CaseClause.canParse(a) || DefaultClause.canParse(a), (a)
			{
				return CaseClause.canParse(a) ? CaseClause.drops(a) : DefaultClause.drops(a);
			});
		if(in3.front.type != TokenType.CloseBrace) return input;
		return in3.dropOne;
	}
	public static TokenList parse(TokenList input)
	{
		return input.consumeToken!(TokenType.Switch)
			.then!(a => Expression.parse(a.consumeToken!(TokenType.OpenParenthese)).consumeToken!(TokenType.CloseParenthese))
			.consumeToken!(TokenType.OpenBrace)
			.thenLoop!(a => CaseClause.canParse(a) || DefaultClause.canParse(a), (a)
			{
				return CaseClause.canParse(a) ? CaseClause.parse(a) : DefaultClause.parse(a);
			})
			.consumeToken!(TokenType.CloseBrace);
	}
}
/// DefaultClause = "default" "=>" Statement
public static class DefaultClause
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.Default;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.front.type != TokenType.Default) return input;
		if(input.dropOne.front.type != TokenType.Equal_RightAngleBracket) return input;
		return Statement.drops(input.drop(2));
	}
	public static TokenList parse(TokenList input)
	{
		return input.consumeToken!(TokenType.Default).consumeToken!(TokenType.Equal_RightAngleBracket)
			.then!(a => Statement.parse(a));
	}
}
/// CaseClause = ValueCaseClause | TypeMatchingCaseClause
public static class CaseClause
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.Case;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.take(3).map!(a => a.type).equal([TokenType.Case, TokenType.Identifier, TokenType.Colon]))
		{
			return TypeMatchingCaseClause.drops(input);
		}
		else return ValueCaseClause.drops(input);
	}
	public static TokenList parse(TokenList input)
	{
		if(input.take(3).map!(a => a.type).equal([TokenType.Case, TokenType.Identifier, TokenType.Colon]))
		{
			return TypeMatchingCaseClause.parse(input);
		}
		else return ValueCaseClause.parse(input);
	}
}
/// ValueCaseClause = "case" ExpressionList "=>" Statement
public static class ValueCaseClause
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.Case;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.front.type != TokenType.Case) return input;
		auto in2 = ExpressionList.drops(input.dropOne);
		if(in2.front.type != TokenType.Equal_RightAngleBracket) return input;
		return Statement.drops(in2.dropOne);
	}
	public static TokenList parse(TokenList input)
	{
		return input.consumeToken!(TokenType.Case)
			.then!(a => ExpressionList.parse(a).consumeToken!(TokenType.Equal_RightAngleBracket))
			.then!(Statement.parse);
	}
}
/// TypeMatchingCaseClause = "case" Identifier ":" Type ("," Identifier ":" Type)* "=>" Statement
public static class TypeMatchingCaseClause
{
	public static bool canParse(TokenList input)
	{
		return input.front.type == TokenType.Case;
	}
	public static TokenList drops(TokenList input)
	{
		if(input.front.type != TokenType.Case) return input;
		if(input.dropOne.front.type != TokenType.Identifier) return input;
		if(input.drop(2).front.type != TokenType.Colon) return input;
		auto in2 = Type.drops(input.drop(3))
			.thenLoop!(a => a.front.type == TokenType.Comma, (a)
			{
				if(a.dropOne.front.type != TokenType.Identifier) return a;
				if(a.drop(2).front.type != TokenType.Colon) return a;
				return Type.drops(a.drop(3));
			});
		if(in2.front.type != TokenType.Equal_RightAngleBracket) return input;
		return Statement.drops(in2.dropOne);
	}
	public static TokenList parse(TokenList input)
	{
		return input.consumeToken!(TokenType.Case).consumeToken!(TokenType.Identifier).consumeToken!(TokenType.Colon)
			.then!(Type.parse)
			.thenLoop!(a => a.front.type == TokenType.Comma,
				a => Type.parse(a.dropOne.consumeToken!(TokenType.Identifier).consumeToken!(TokenType.Colon)))
			.then!(a => Statement.parse(a.consumeToken!(TokenType.Equal_RightAngleBracket)));
	}
}
