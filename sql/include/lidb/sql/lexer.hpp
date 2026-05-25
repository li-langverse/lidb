#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace lidb::sql {

enum class TokenKind {
  kEof,
  kIdent,
  kString,
  kNumber,
  kStar,
  kComma,
  kLParen,
  kRParen,
  kSemi,
  kEq,
  kKwSelect,
  kKwFrom,
  kKwWhere,
  kKwInsert,
  kKwInto,
  kKwValues,
};

struct Token {
  TokenKind kind{TokenKind::kEof};
  std::string text;
  std::size_t pos{0};
};

class Lexer {
 public:
  explicit Lexer(std::string_view input);
  Token next();
  void put_back(Token t);

 private:
  std::string_view input_;
  std::size_t pos_{0};
  std::optional<Token> putback_;
  void skip_space();
  Token read_ident_or_kw();
  Token read_string();
  Token read_number();
  char peek() const;
  char get();
};

}  // namespace lidb::sql
