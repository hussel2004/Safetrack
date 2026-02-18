# Implementation Plan - SafeTrack

## Goal Description
Build a Flutter mobile application "SafeTrack" that allows users to register, register their vehicles, view GPS positions, define secure zones, and remotely stop the vehicle. The application will use mock data and services.
**Key Focus**: The UI must be professional, modern, and aesthetically pleasing, avoiding generic "basic" looks.

## User Review Required
> [!NOTE]
> We will be using Mock Services to simulate Backend interactions. No real data will be persisted across app restarts unless we use local storage (shared_preferences/sqlite). for now, in-memory mock is assumed sufficient.

## Proposed Changes

### Project Setup
- Initialize Flutter project in `Frontend` directory.
- Structure:
    - `lib/models`: Data structures.
    - `lib/services`: Mock services for data fetching.
    - `lib/providers`: State management.
    - `lib/screens`: UI pages.
    - `lib/widgets`: Reusable UI components.

### Dependencies
- `provider`: For state management.
- `uuid`: For generating unique IDs.
- `random_name_generator` (optional): For mock data generation? (Or just hardcode/randomize manually).

### Features & Components

#### 0. Design & UI/UX
- **Theme**: Dark/Light mode support with a premium color palette (e.g., Deep Navy, Teal, Alabaster).
- **Typography**: Modern sans-serif font (e.g., Poppins or Lato).
- **Components**: Rounded corners, soft shadows, glassmorphism effects where appropriate.
- **Animations**: Smooth page transitions, hero animations for vehicle details.

#### 1. Models
- `User`: id, username, email.
- `Vehicle`: id, ownerId, model, licensePlate, gpsId, `secureZoneRadius` (double), `secureZoneCenter` (Lat/Lng).
- `GpsPosition`: vehicleId, latitude, longitude, timestamp.

#### 2. Mock Services
- `AuthService`: `login`, `register`. Stores users in memory.
- `VehicleService`: `registerVehicle`, `getVehiclesForUser`, `updateSecureZone`.
- `GpsService`: `getPositions`, `streamPositions`. Generates coordinates. Checks distance vs `secureZoneRadius`. Triggers alert if outside.
- `CommandService`: `stopEngine(vehicleId)`. Simulates sending command to IoT.

#### 3. Screens
- `LoginScreen` / `RegisterScreen`: Simple forms.
- `VehicleRegistrationScreen`: Form to add a car.
- `DashboardScreen`: 
    - List of vehicles.
    - GPS Map/Text View.
    - **Vehicle Detail View**:
        - "Define Secure Zone" button/input (Set current location as center + radius).
        - **Red "STOP VEHICLE" Button**.

## Verification Plan
### Manual Verification
- **Registration**: Register a new user and login.
- **Vehicle**: Add a vehicle and see it in the list.
- **GPS**: Observe GPS coordinates updating.
- **Secure Zone**: Set a small radius, wait for mock GPS to drift outside, verify Alert.
- **Stop**: Click Red Button, verify "Command Sent" success message.
