#include "lidb/sql/lexer.hpp"

#include <cctype>

namespace lidb::sql {

Lexer::Lexer(std::string_view input) : input_(input) {}

char Lexer::peek() const {
  if (pos_ >= input_.size()) return '\0';
  return input_[pos_];
}

char Lexer::get() {
  if (pos_ >= input_.size()) return '\0';
  return input_[pos_++];
}

void Lexer::skip_space() {
  while (pos_ < input_.size()) {
    char c = input_[pos_];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      ++pos_;
      continue;
    }
    break;
  }
}

Token Lexer::read_string() {
  const std::size_t start = pos_;
  get();
  std::string text;
  while (pos_ < input_.size()) {
    char c = get();
    if (c == '\0') break;
    if (c == '"') {
      if (peek() == '"') {
        get();
        text.push_back('"');
        continue;
      }
      break;
    }
    text.push_back(c);
  }
  return Token{TokenKind::kString, text, start};
}

Token Lexer::read_number() {
  const std::size_t start = pos_;
  std::string text;
  while (pos_ < input_.size() && std::isdigit(static_cast<unsigned char>(peek()))) {
    text.push_back(get());
  }
  if (peek() == '.') {
    text.push_back(get());
    while (pos_ < input_.size() && std::isdigit(static_cast<unsigned char>(peek()))) {
      text.push_back(get());
    }
  }
  return Token{TokenKind::kNumber, text, start};
}

Token Lexer::read_ident_or_kw() {
  const std::size_t start = pos_;
  std::string text;
  if (peek() == '"') return read_string();
  while (pos_ < input_.size()) {
    char c = peek();
    if (std::isalnum(static_cast<unsigned char>(c)) || c == '_') {
      text.push_back(get());
      continue;
    }
    break;
  }
  auto lower = text;
  for (auto& ch : lower) ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  if (lower == "select") return Token{TokenKind::kKwSelect, text, start};
  if (lower == "from") return Token{TokenKind::kKwFrom, text, start};
  if (lower == "where") return Token{TokenKind::kKwWhere, text, start};
  if (lower == "insert") return Token{TokenKind::kKwInsert, text, start};
  if (lower == "into") return Token{TokenKind::kKwInto, text, start};
  if (lower == "values") return Token{TokenKind::kKwValues, text, start};
  return Token{TokenKind::kIdent, text, start};
}

void Lexer::put_back(Token t) { putback_ = std::move(t); }

Token Lexer::next() {
  if (putback_) {
    Token t = *putback_;
    putback_.reset();
    return t;
  }
  skip_space();
  const std::size_t start = pos_;
  if (pos_ >= input_.size()) return Token{TokenKind::kEof, "", start};
  char c = peek();
  if (c == '*') {
    get();
    return Token{TokenKind::kStar, "*", start};
  }
  if (c == ',') {
    get();
    return Token{TokenKind::kComma, ",", start};
  }
  if (c == '(') {
    get();
    return Token{TokenKind::kLParen, "(", start};
  }
  if (c == ')') {
    get();
    return Token{TokenKind::kRParen, ")", start};
  }
  if (c == ';') {
    get();
    return Token{TokenKind::kSemi, ";", start};
  }
  if (c == '=') {
    get();
    return Token{TokenKind::kEq, "=", start};
  }
  if (c == '?') {
    get();
    return Token{TokenKind::kIdent, "?", start};
  }
  if (c == '$' && pos_ + 1 < input_.size() && std::isdigit(static_cast<unsigned char>(input_[pos_ + 1]))) {
    std::string text;
    text.push_back(get());
    while (pos_ < input_.size() && std::isdigit(static_cast<unsigned char>(peek()))) {
      text.push_back(get());
    }
    return Token{TokenKind::kIdent, text, start};
  }
  if (c == '\'') {
    get();
    std::string text;
    while (pos_ < input_.size()) {
      char ch = get();
      if (ch == '\0') break;
      if (ch == '\'') {
        if (peek() == '\'') {
          get();
          text.push_back('\'');
          continue;
        }
        break;
      }
      text.push_back(ch);
    }
    return Token{TokenKind::kString, text, start};
  }
  if (std::isdigit(static_cast<unsigned char>(c))) return read_number();
  if (std::isalpha(static_cast<unsigned char>(c)) || c == '_') return read_ident_or_kw();
  get();
  return Token{TokenKind::kIdent, std::string(1, c), start};
}

}  // namespace lidb::sql
