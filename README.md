# Appointment Booking System

A modern, full-featured appointment booking system built with **Elixir**, **Phoenix**, and **LiveView**.

## 🚀 Features

### **Customer Experience**
- **Modern booking interface** with step-by-step process
- **Real-time availability** with smart time slot selection  
- **Mobile-first design** optimized for all devices
- **24-hour time format** with duration display
- **Instant confirmation** with booking summary

### **Admin Dashboard**
- **Weekly availability management** with Calendly-inspired interface
- **Real-time statistics** (total appointments, available slots, today's bookings)
- **Smart time slot generation** from weekly patterns
- **Individual slot management** with instant database updates
- **Mobile-responsive admin interface**

### **Technical Features**
- **Auto-save functionality** for all changes
- **Conflict prevention** - no overlapping time slots
- **Database persistence** with PostgreSQL
- **Real-time updates** using Phoenix LiveView
- **Military time format** (0900, 1730) throughout system

## 🏗️ System Architecture

### **Database Tables**
- `weekly_availability` - Weekly schedule patterns
- `time_slots` - Individual bookable appointments  
- `appointments` - Customer bookings

### **Key Routes**
- `/` - Landing page
- `/book` - Customer booking interface
- `/admin` - Admin dashboard with statistics
- `/admin/availability` - Weekly schedule management

## 🛠️ Setup Instructions

### **Prerequisites**
- Elixir 1.18+
- Phoenix Framework
- PostgreSQL database

### **Installation**

1. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd hello
   mix setup
   ```

2. **Database setup**:
   ```bash
   mix ecto.migrate
   ```

3. **Start the server**:
   ```bash
   mix phx.server
   ```

4. **Visit the application**:
   - Main app: [`localhost:4000`](http://localhost:4000)
   - Booking interface: [`localhost:4000/book`](http://localhost:4000/book)
   - Admin dashboard: [`localhost:4000/admin`](http://localhost:4000/admin)
   - Weekly availability: [`localhost:4000/admin/availability`](http://localhost:4000/admin/availability)

## 📖 Usage Guide

### **Setting Up Availability**

1. **Go to Admin Availability** (`/admin/availability`)
2. **Configure weekly schedule**:
   - Toggle days on/off
   - Set multiple time ranges per day
   - Times auto-save to database
3. **Generate time slots** - Creates bookable appointments for next 8 weeks
4. **View in admin dashboard** - See generated slots and bookings

### **Customer Booking Flow**

1. **Select time** - Browse available slots grouped by date
2. **Enter details** - Name, email, phone, notes
3. **Confirm booking** - Instant confirmation with summary
4. **Email notification** - Confirmation sent automatically

### **Admin Management**

- **Dashboard** - View statistics and recent appointments
- **Availability** - Manage weekly schedule patterns  
- **Real-time updates** - All changes reflect immediately
- **Mobile admin** - Full functionality on mobile devices

## 🎨 Design Features

### **Modern UI/UX**
- **Clean white backgrounds** throughout
- **Mobile-first responsive design**
- **Professional card layouts**
- **Intuitive navigation** and progress indicators

### **Smart Interactions**
- **Auto-save** on every change
- **Conflict prevention** for time slots
- **Loading states** and visual feedback
- **One-click time selection**

## 🔧 Technical Stack

- **Backend**: Elixir/Phoenix Framework
- **Frontend**: Phoenix LiveView + Tailwind CSS
- **Database**: PostgreSQL with Ecto
- **Real-time**: Phoenix LiveView for instant updates
- **Deployment**: Ready for production deployment

## 📝 Development Notes

### **Key LiveView Modules**
- `AdminLive` - Dashboard and statistics
- `AvailabilityLive` - Weekly schedule management
- `BookingLive` - Customer booking interface

### **Database Context**
- `Hello.Appointments` - Main business logic
- Auto-generation of time slots from weekly patterns
- Conflict prevention and validation

### **Time Format**
- Military time throughout (0900, 1730)
- 30-minute minimum appointment duration
- Smart end-time calculation (start + 30 minutes default)

## 🚦 Getting Started Workflow

1. **Start server**: `mix phx.server`
2. **Set availability**: Visit `/admin/availability` 
3. **Configure schedule**: Set your weekly working hours
4. **Generate slots**: Click "Generate Time Slots" 
5. **Test booking**: Visit `/book` to test customer experience
6. **Monitor**: Check `/admin` for bookings and statistics

## 📱 Mobile Support

- **Fully responsive** design on all pages
- **Touch-optimized** controls and interactions
- **Mobile-first** CSS with proper breakpoints
- **Fast performance** on mobile devices

## 🔐 Production Ready

- **Database migrations** included
- **Error handling** and validation
- **Security considerations** implemented
- **Performance optimized** queries and updates

## 📞 Support & Documentation

For additional help:
- **Phoenix Framework**: [https://phoenixframework.org](https://phoenixframework.org)
- **LiveView Guide**: [https://hexdocs.pm/phoenix_live_view](https://hexdocs.pm/phoenix_live_view)
- **Elixir Documentation**: [https://elixir-lang.org](https://elixir-lang.org)