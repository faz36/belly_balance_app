# 🌿 Belly Balance
> A daily nutrition app for pregnant mothers — designed specifically to help expectant mothers in Malaysia track calories and essential nutrients throughout pregnancy.
<br>

## 📱 Screenshots
<table>
  <tr>
    <td align="center"><b>Login</b></td>
    <td align="center"><b>Register Account</b></td>
    <td align="center"><b>Profile Setup</b></td>
  </tr>
  <tr>
    <td><img src="screenshots/01_login.png" width="220"/></td>
    <td><img src="screenshots/02_signup.png" width="220"/></td>
    <td><img src="screenshots/03_setup.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Home</b></td>
    <td align="center"><b>Nutrition Log</b></td>
    <td align="center"><b>Food List</b></td>
  </tr>
  <tr>
    <td><img src="screenshots/04_home.png" width="220"/></td>
    <td><img src="screenshots/05_nutrition.png" width="220"/></td>
    <td><img src="screenshots/06_food_list.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Add Food</b></td>
    <td align="center"><b>Nutrition History</b></td>
    <td align="center"><b>Profile</b></td>
  </tr>
  <tr>
    <td><img src="screenshots/07_custom_food.png" width="220"/></td>
    <td><img src="screenshots/08_history.png" width="220"/></td>
    <td><img src="screenshots/09_profile.png" width="220"/></td>
  </tr>
</table>
<br>

## ✨ Features
- 🔐 **Authentication** — Register & log in with email/password or Google Sign-In
- 🥗 **Nutrition Log** — Choose from a database of 350+ Malaysian foods & log daily meals
- 🍽️ **Custom Foods** — Add, edit & delete custom food entries to suit personal preferences
- 📊 **Calorie Summary** — Track daily calories vs target by trimester (T1: 1800 / T2: 2200 / T3: 2400 kcal)
- 💊 **Essential Nutrients** — Track protein, carbohydrates, fat, fiber, calcium, iron & folate
- 📋 **History** — View past nutrition records, daily streaks & weekly analysis
- 👤 **Profile** — Update weight & height, with automatic BMI calculation
- 💡 **Nutrition Tips** — Dietary recommendations based on trimester
<br>

## 🛠️ Tech Stack
| | |
|---|---|
| **Framework** | Flutter (Dart) |
| **Backend** | Firebase Firestore |
| **Auth** | Firebase Authentication + Google Sign-In |
| **State Management** | Provider |
| **Font** | Poppins |
<br>

## 📂 Project Structure
```
lib/
├── main.dart
├── pages/
│   ├── home_page.dart
│   ├── nutrition_page.dart
│   ├── history_page.dart
│   ├── profile_page.dart
│   ├── login_page.dart
│   └── signup_page.dart
├── providers/
│   └── user_provider.dart
├── services/
│   └── auth_service.dart
└── wrappers/
    └── main_wrapper.dart
```
<br>

## 🚀 Getting Started
### Prerequisites
- Flutter SDK `>=3.0.0`
- Firebase project with Firestore & Authentication enabled

### Setup
```bash
# Clone repo
git clone https://github.com/faz36/belly_balance_app.git
cd belly_balance_app

# Install dependencies
flutter pub get

# Run app
flutter run
```
> ⚠️ **Note:** You will need to set up your own `google-services.json` from the Firebase Console and place it inside `android/app/`.
<br>

## 🗄️ Database
The food database contains **350+ Malaysian foods** spanning 21 categories:

Rice & Grains · Side Dishes · Meat & Protein · Fish & Seafood · Vegetables · Fruits · Dairy & Milk · Malaysian Fast Food · Desserts & Kuih · and many more
<br>

## 👩‍💻 Developer
**Faz** — [@faz36](https://github.com/faz36)

<br>

---
<p align="center">Made with ❤️ for expectant mothers in Malaysia</p>
