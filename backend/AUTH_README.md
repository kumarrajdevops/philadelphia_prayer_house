# 🔐 Authentication System Documentation

## Overview

The Philadelphia Prayer House backend now supports **dual authentication methods**:
1. **Password-based authentication** (traditional username/password)
2. **OTP-based authentication** (SMS/Email OTP)

Both methods use JWT tokens for session management.

---

## 🔑 Authentication Methods

### 1. Password-Based Authentication

#### Register
```http
POST /auth/register
Content-Type: application/json

{
  "name": "John Doe",
  "username": "johndoe",
  "password": "securepassword123",
  "phone": "+1234567890",  // Optional
  "email": "john@example.com",  // Optional
  "role": "member"  // Default: "member"
}
```

#### Login
```http
POST /auth/login
Content-Type: application/x-www-form-urlencoded

username=johndoe&password=securepassword123
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer",
  "user_id": 1,
  "username": "johndoe",
  "role": "member"
}
```

---

### 2. OTP-Based Authentication

#### Step 1: Request OTP
```http
POST /auth/otp/request
Content-Type: application/json

{
  "phone": "+1234567890"  // OR "email": "user@example.com"
}
```

**Response:**
```json
{
  "message": "OTP sent successfully",
  "expires_in_minutes": 10
}
```

#### Step 2: Verify OTP & Login/Register
```http
POST /auth/otp/verify
Content-Type: application/json

{
  "otp_code": "123456",
  "phone": "+1234567890",  // OR "email": "user@example.com"
  "name": "John Doe",  // Required for new users
  "username": "johndoe"  // Required for new users
}
```

**Response:** Same as password login (JWT tokens)

**Note:** If user doesn't exist, they will be automatically registered. If user exists, they will be logged in.

---

## 🔄 Token Management

### Refresh Token
```http
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Get Current User
```http
GET /auth/me
Authorization: Bearer <access_token>
```

---

## 📋 API Endpoints Summary

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/auth/register` | POST | Register with password | No |
| `/auth/login` | POST | Login with password | No |
| `/auth/otp/request` | POST | Request OTP | No |
| `/auth/otp/verify` | POST | Verify OTP & login/register | No |
| `/auth/refresh` | POST | Refresh access token | No |
| `/auth/me` | GET | Get current user info | Yes |

---

## 🔧 Configuration

Environment variables (see `.env.example`):

```env
# JWT Settings
SECRET_KEY=your-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=1440  # 24 hours
REFRESH_TOKEN_EXPIRE_DAYS=30

# OTP Settings
OTP_LENGTH=6
OTP_EXPIRE_MINUTES=10
OTP_MAX_ATTEMPTS=3

# SMS/Email (set to true when ready)
SMS_ENABLED=false
EMAIL_ENABLED=false
```

---

## 🛡️ Security Features

1. **Password Hashing:** Bcrypt with passlib
2. **JWT Tokens:** Signed with HS256 algorithm
3. **OTP Expiration:** 10 minutes default
4. **Token Refresh:** Long-lived refresh tokens
5. **User Status:** `is_active` flag for account control

---

## 📱 Usage in Flutter App

### Password Login Example
```dart
final response = await http.post(
  Uri.parse('$baseUrl/auth/login'),
  headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  body: {
    'username': username,
    'password': password,
  },
);
```

### OTP Login Example
```dart
// Step 1: Request OTP
await http.post(
  Uri.parse('$baseUrl/auth/otp/request'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'phone': phoneNumber}),
);

// Step 2: Verify OTP
final response = await http.post(
  Uri.parse('$baseUrl/auth/otp/verify'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'otp_code': otpCode,
    'phone': phoneNumber,
    'name': name,  // For new users
    'username': username,  // For new users
  }),
);
```

### Using Token in Requests
```dart
final response = await http.get(
  Uri.parse('$baseUrl/auth/me'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);
```

---

## 🚀 Next Steps

1. **SMS Integration:** Integrate with Twilio/AWS SNS for production SMS
2. **Email Integration:** Integrate with SendGrid/AWS SES for production emails
3. **Rate Limiting:** Add rate limiting for OTP requests
4. **2FA:** Add two-factor authentication option
5. **Social Login:** Add Google/Facebook login (optional)

---

## ✅ Features Implemented

- ✅ Password-based registration & login
- ✅ OTP-based registration & login
- ✅ JWT access & refresh tokens
- ✅ User profile management
- ✅ Phone & email support
- ✅ OTP expiration & verification
- ✅ CORS configuration for mobile app
- ✅ Environment-based configuration

---

**Status:** ✅ Ready for use!

